#!/usr/bin/env bats
# test_idle_auto_clear.bats — idle足軽 自動/clear 機構 ユニットテスト (cmd_585 Phase2)
#
# 設計仕様書: .shogun/tmp/cmd_585_auto_clear_design.md §10 (T01-T18)
# 第一目標: 誤clearゼロ。NO-CLEAR系 (T04-T10/T13/T14/T15/T16/T17/T18) が生命線。
#
# 方式: scripts/idle_auto_clear.sh を __IDLE_AUTO_CLEAR_TESTING__=1 で source し、
#       判定→送出フロー evaluate_and_maybe_clear / scan_all_targets を直接駆動。
#       send_clear / record_clear はスタブ化し「呼ばれたか」を SEND_LOG で検証。
#       idle_age は idle flag の mtime を python os.utime で任意設定して注入。

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/scripts/idle_auto_clear.sh"

setup_file() {
    export PROJECT_ROOT="$SCRIPT_DIR"
    export VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python3"
    [ -f "$TARGET_SCRIPT" ] || return 1
    [ -x "$VENV_PYTHON" ] || return 1
    "$VENV_PYTHON" -c "import yaml" 2>/dev/null || return 1
}

setup() {
    TMP="$(mktemp -d "$BATS_TMPDIR/auto_clear.XXXXXX")"
    export AUTO_CLEAR_QUEUE_DIR="$TMP/queue"
    export IDLE_FLAG_DIR="$TMP/flags"
    export AUTO_CLEAR_STATE_FILE="$TMP/queue/metrics/auto_clear_state.yaml"
    export AUTO_CLEAR_LOG_FILE="$TMP/logs/idle_auto_clear.log"
    export AUTO_CLEAR_PYTHON="$SCRIPT_DIR/.venv/bin/python3"
    export SEND_LOG="$TMP/send.log"
    export HARNESS="$TMP/harness.sh"

    mkdir -p "$AUTO_CLEAR_QUEUE_DIR/tasks" "$AUTO_CLEAR_QUEUE_DIR/inbox" \
             "$AUTO_CLEAR_QUEUE_DIR/metrics" "$IDLE_FLAG_DIR" "$TMP/logs"
    : > "$SEND_LOG"

    # ── テストハーネス: 環境を引き継ぎ、スクリプトを source し、スタブ/fixtureヘルパを定義 ──
    cat > "$HARNESS" << HARNESS_EOF
#!/usr/bin/env bash
export __IDLE_AUTO_CLEAR_TESTING__=1
# shellcheck disable=SC1090
source "$TARGET_SCRIPT"

# ── 送出系スタブ: 実際の inbox_write / state書込は行わず呼出記録のみ ──
send_clear() { echo "\$1" >> "$SEND_LOG"; return 0; }
record_clear() { return 0; }

# ── tmux/timeout スタブ (verify_pane / footer hint ケース用) ──
timeout() { shift; "\$@"; }
tmux() {
    case "\$*" in
        *capture-pane*)
            if [ "\${MOCK_PANE_FAIL:-0}" = "1" ]; then return 1; fi
            printf '%s\n' "\${MOCK_PANE_OUT:-}"
            return 0 ;;
        *show-options*) echo 0; return 0 ;;
        *) return 0 ;;
    esac
}
pane_for() { echo "test:0.0"; }
sleep() { :; }

# ── fixtureヘルパ ──
write_task() {   # write_task <agent> <status>
    mkdir -p "$AUTO_CLEAR_QUEUE_DIR/tasks"
    cat > "$AUTO_CLEAR_QUEUE_DIR/tasks/\${1}.yaml" <<TASK
task:
  task_id: t_\${1}
  status: \${2}
TASK
}
write_inbox() {  # write_inbox <agent> <unread_count>
    mkdir -p "$AUTO_CLEAR_QUEUE_DIR/inbox"
    {
        echo "messages:"
        local i
        for ((i=0; i<\${2}; i++)); do
            echo "- {id: m\$i, read: false, from: karo}"
        done
        echo "- {id: mr, read: true, from: karo}"
    } > "$AUTO_CLEAR_QUEUE_DIR/inbox/\${1}.yaml"
}
set_flag() {     # set_flag <agent> <age_sec> (負値=フラグ無し)
    local flag="$IDLE_FLAG_DIR/shogun_idle_\${1}"
    if [ "\${2}" -lt 0 ]; then rm -f "\$flag"; return 0; fi
    : > "\$flag"
    "$AUTO_CLEAR_PYTHON" -c "import os,time,sys; t=time.time()-float(sys.argv[1]); os.utime(sys.argv[2],(t,t))" "\${2}" "\$flag"
}
write_state() {  # write_state <agent> <last_clear_age_sec>
    mkdir -p "$(dirname "$AUTO_CLEAR_STATE_FILE")"
    local ts=\$(( \$(date +%s) - \${2} ))
    cat > "$AUTO_CLEAR_STATE_FILE" <<ST
agents:
  \${1}:
    last_clear_ts: \${ts}
    clear_count: 1
ST
}
HARNESS_EOF
}

teardown() {
    rm -rf "$TMP"
}

assert_cleared() {     # assert_cleared <agent>
    grep -qx "$1" "$SEND_LOG" || {
        echo "expected CLEAR for $1, SEND_LOG=$(cat "$SEND_LOG")" >&2
        return 1
    }
}
assert_not_cleared() { # assert_not_cleared <agent>
    if grep -qx "$1" "$SEND_LOG"; then
        echo "unexpected CLEAR for $1, SEND_LOG=$(cat "$SEND_LOG")" >&2
        return 1
    fi
}

# ─── T01: done + idle放置35分 + 安全 → CLEAR (T1主軸) ───
@test "T01: done idle 35min safe -> CLEAR" {
    run bash -c "source '$HARNESS'; write_task ashigaru1 done; write_inbox ashigaru1 0; set_flag ashigaru1 2100; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_cleared ashigaru1
}

# ─── T02: placeholder idle も対象 → CLEAR ───
@test "T02: status idle (placeholder) -> CLEAR" {
    run bash -c "source '$HARNESS'; write_task ashigaru1 idle; write_inbox ashigaru1 0; set_flag ashigaru1 2100; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_cleared ashigaru1
}

# ─── T03: failed 放置も回収 → CLEAR ───
@test "T03: failed idle 35min -> CLEAR" {
    run bash -c "source '$HARNESS'; write_task ashigaru1 failed; write_inbox ashigaru1 0; set_flag ashigaru1 2100; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_cleared ashigaru1
}

# ─── T04: assigned (作業中) → NO-CLEAR (S1) ───
@test "T04: assigned -> NO-CLEAR (S1 working)" {
    run bash -c "source '$HARNESS'; write_task ashigaru1 assigned; write_inbox ashigaru1 0; set_flag ashigaru1 2100; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T05: in_progress 長時間でも作業中はNG → NO-CLEAR (S1) ───
@test "T05: in_progress 99min -> NO-CLEAR (S1)" {
    run bash -c "source '$HARNESS'; write_task ashigaru1 in_progress; write_inbox ashigaru1 0; set_flag ashigaru1 5940; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T06: blocked は作業文脈保持 → NO-CLEAR (S1) ───
@test "T06: blocked 99min -> NO-CLEAR (S1)" {
    run bash -c "source '$HARNESS'; write_task ashigaru1 blocked; write_inbox ashigaru1 0; set_flag ashigaru1 5940; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T07: 未読あり → NO-CLEAR (S2 メッセージ消失防止) ───
@test "T07: unread=2 -> NO-CLEAR (S2)" {
    run bash -c "source '$HARNESS'; write_task ashigaru1 done; write_inbox ashigaru1 2; set_flag ashigaru1 2100; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T08: idle flag 無し (=busy) → NO-CLEAR (S3) ───
@test "T08: no idle flag -> NO-CLEAR (S3 busy)" {
    run bash -c "source '$HARNESS'; write_task ashigaru1 done; write_inbox ashigaru1 0; set_flag ashigaru1 -1; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T09: grace未満(5分)の偽idle → NO-CLEAR (S4) ───
@test "T09: idle 5min < grace -> NO-CLEAR (S4)" {
    run bash -c "source '$HARNESS'; write_task ashigaru1 done; write_inbox ashigaru1 0; set_flag ashigaru1 300; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T10: cooldown中(3分前にclear) → NO-CLEAR (S5) ───
@test "T10: cooldown active (cleared 3min ago) -> NO-CLEAR (S5)" {
    run bash -c "source '$HARNESS'; write_task ashigaru1 done; write_inbox ashigaru1 0; set_flag ashigaru1 2100; write_state ashigaru1 180; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T11: 安全だが非肥大 (idle 20分 grace超bloat未満) → NO-CLEAR ───
@test "T11: safe but not bloated (idle 20min) -> NO-CLEAR" {
    run bash -c "source '$HARNESS'; write_task ashigaru1 done; write_inbox ashigaru1 0; set_flag ashigaru1 1200; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T12: footer hint 有 + enabled=true (idle 20分) → CLEAR (T2) ───
@test "T12: footer hint + enabled -> CLEAR (T2)" {
    run bash -c "source '$HARNESS'; AUTO_CLEAR_FOOTER_HINT_ENABLED=true; AUTO_CLEAR_FOOTER_HINT_PATTERNS=('Context left until auto-compact'); MOCK_PANE_OUT='blah Context left until auto-compact 5%'; write_task ashigaru1 done; write_inbox ashigaru1 0; set_flag ashigaru1 1200; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_cleared ashigaru1
}

# ─── T13: footer hint 有だが enabled=false → NO-CLEAR (安全側) ───
@test "T13: footer hint present but enabled=false -> NO-CLEAR" {
    run bash -c "source '$HARNESS'; AUTO_CLEAR_FOOTER_HINT_ENABLED=false; MOCK_PANE_OUT='Context left until auto-compact 5%'; write_task ashigaru1 done; write_inbox ashigaru1 0; set_flag ashigaru1 1200; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T14: verify_pane=true で pane が "esc to" 表示 → NO-CLEAR (S6) ───
@test "T14: verify_pane busy (esc to) -> NO-CLEAR (S6)" {
    run bash -c "source '$HARNESS'; AUTO_CLEAR_VERIFY_PANE=true; MOCK_PANE_OUT='Working (5s esc to interrupt)'; write_task ashigaru1 done; write_inbox ashigaru1 0; set_flag ashigaru1 2100; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T15: verify_pane=true で pane取得失敗 → NO-CLEAR (S6 安全側) ───
@test "T15: verify_pane read fail -> NO-CLEAR (S6 fail-safe)" {
    run bash -c "source '$HARNESS'; AUTO_CLEAR_VERIFY_PANE=true; MOCK_PANE_FAIL=1; write_task ashigaru1 done; write_inbox ashigaru1 0; set_flag ashigaru1 2100; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T16: targets外 (karo) は scan対象外 → NO-CLEAR ───
@test "T16: non-target karo excluded by scan -> NO-CLEAR" {
    run bash -c "source '$HARNESS'; AUTO_CLEAR_ENABLED=true; AUTO_CLEAR_TARGETS=(ashigaru1); write_task ashigaru1 done; write_inbox ashigaru1 0; set_flag ashigaru1 2100; write_task karo done; write_inbox karo 0; set_flag karo 2100; scan_all_targets"
    [ "$status" -eq 0 ]
    assert_cleared ashigaru1
    assert_not_cleared karo
}

# ─── T17: enabled=false → scan は何もしない → NO-CLEAR ───
@test "T17: enabled=false -> NO-CLEAR (global off)" {
    run bash -c "source '$HARNESS'; AUTO_CLEAR_ENABLED=false; AUTO_CLEAR_TARGETS=(ashigaru1); write_task ashigaru1 done; write_inbox ashigaru1 0; set_flag ashigaru1 2100; scan_all_targets"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T18: double-check で送出直前のassigned化を捕捉 → NO-CLEAR (P3レース) ───
@test "T18: double-check catches race (done->assigned) -> NO-CLEAR" {
    run bash -c "source '$HARNESS'; write_task ashigaru1 done; write_inbox ashigaru1 0; set_flag ashigaru1 2100; is_bloated() { write_task ashigaru1 assigned; TRIGGER='forced'; return 0; }; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T20 (追補): inbox不在 → NO-CLEAR (S2 fail-safe) ───
@test "T20: missing inbox file -> NO-CLEAR (S2 fail-safe)" {
    # write_inbox を呼ばず inbox を不在にする (task/flag は clear 適格)
    run bash -c "source '$HARNESS'; write_task ashigaru1 done; set_flag ashigaru1 2100; evaluate_and_maybe_clear ashigaru1"
    [ "$status" -eq 0 ]
    assert_not_cleared ashigaru1
}

# ─── T19 (追補): record_clear + cooldown 往復が機能する (設計検証手順4) ───
@test "T19: record_clear writes state and cooldown blocks next clear" {
    # 実体の record_clear を使った往復確認 (send_clearはスタブ、record_clearは実体)
    run bash -c "
        export __IDLE_AUTO_CLEAR_TESTING__=1
        source '$TARGET_SCRIPT'
        send_clear() { echo \"\$1\" >> '$SEND_LOG'; return 0; }
        sleep() { :; }
        # fixture
        mkdir -p '$AUTO_CLEAR_QUEUE_DIR/tasks' '$AUTO_CLEAR_QUEUE_DIR/inbox'
        printf 'task:\n  task_id: t1\n  status: done\n' > '$AUTO_CLEAR_QUEUE_DIR/tasks/ashigaru1.yaml'
        printf 'messages:\n- {id: mr, read: true, from: karo}\n' > '$AUTO_CLEAR_QUEUE_DIR/inbox/ashigaru1.yaml'
        : > '$IDLE_FLAG_DIR/shogun_idle_ashigaru1'
        '$AUTO_CLEAR_PYTHON' -c 'import os,time; t=time.time()-2100; os.utime(\"$IDLE_FLAG_DIR/shogun_idle_ashigaru1\",(t,t))'
        # 1回目: clear されて state 記録
        evaluate_and_maybe_clear ashigaru1
        # 2回目: cooldown により clear されない
        evaluate_and_maybe_clear ashigaru1
    "
    [ "$status" -eq 0 ]
    # state ファイルが書かれている
    [ -f "$AUTO_CLEAR_STATE_FILE" ]
    grep -q "last_clear_ts" "$AUTO_CLEAR_STATE_FILE"
    # send は1回だけ (2回目はcooldownでブロック)
    [ "$(grep -cx ashigaru1 "$SEND_LOG")" -eq 1 ]
}

# ─── load_config: settings.yaml の auto_clear ブロックを読む ───
@test "load_config reads auto_clear block from settings.yaml" {
    local settings="$TMP/settings.yaml"
    cat > "$settings" << 'YAML'
language: ja
auto_clear:
  enabled: true
  interval_sec: 90
  idle_grace_min: 12
  bloat_idle_min: 25
  cooldown_min: 8
  verify_pane: false
  footer_hint_enabled: false
  token_threshold_k: 0
  targets:
    - ashigaru1
    - ashigaru3
YAML
    run bash -c "export __IDLE_AUTO_CLEAR_TESTING__=1; export AUTO_CLEAR_SETTINGS='$settings'; source '$TARGET_SCRIPT'; load_config; echo \"E=\$AUTO_CLEAR_ENABLED I=\$AUTO_CLEAR_INTERVAL_SEC G=\$AUTO_CLEAR_IDLE_GRACE_MIN B=\$AUTO_CLEAR_BLOAT_IDLE_MIN C=\$AUTO_CLEAR_COOLDOWN_MIN N=\${#AUTO_CLEAR_TARGETS[@]} T0=\${AUTO_CLEAR_TARGETS[0]} T1=\${AUTO_CLEAR_TARGETS[1]}\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"E=true"* ]]
    [[ "$output" == *"I=90"* ]]
    [[ "$output" == *"G=12"* ]]
    [[ "$output" == *"B=25"* ]]
    [[ "$output" == *"C=8"* ]]
    [[ "$output" == *"N=2"* ]]
    [[ "$output" == *"T0=ashigaru1"* ]]
    [[ "$output" == *"T1=ashigaru3"* ]]
}
