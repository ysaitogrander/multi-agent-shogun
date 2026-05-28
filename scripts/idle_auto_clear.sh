#!/usr/bin/env bash
# idle_auto_clear.sh — idle足軽 自動/clear 判定専用デーモン (cmd_585 Phase2)
#
# 設計仕様書: .shogun/tmp/cmd_585_auto_clear_design.md (gunshi / Phase1)
# 第一目標: 誤clearゼロ (安全性 > 機能性)。
#
# 役割:
#   - idle 状態で context 肥大した足軽を検出し、`clear_command` を inbox_write するだけ。
#   - tmux send-keys は一切触らない。送出は既存 inbox_watcher の二重 busy guard /
#     CLI 変換 / shogun 遮断 / auto-recovery に委譲する (設計 §2.4 / §6)。
#   - 対象は足軽のみ (ashigaru1-7)。karo/gunshi/shogun はスコープ外 (設計 §9)。
#
# 安全保証 (設計 §4.2):
#   - 安全ゲート (status / 未読0 / 非busy / idle継続 / cooldown / 任意pane確認) の
#     AND short-circuit + 送出直前の double-check で誤clearを構造的に排除する。
#
# テスト容易性:
#   - __IDLE_AUTO_CLEAR_TESTING__=1 で source すると main を実行しない。
#   - 判定純粋関数 is_safe_to_clear / is_bloated は副作用なし。閾値は AUTO_CLEAR_* 変数で注入可能。
#   - パスは AUTO_CLEAR_QUEUE_DIR / IDLE_FLAG_DIR / AUTO_CLEAR_STATE_FILE /
#     AUTO_CLEAR_LOG_FILE の環境変数で上書き可能。

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# パス基準 (設計 §2.6: 稼働中watcherの SCRIPT_DIR を正とする)
# ─────────────────────────────────────────────────────────────
IDLE_AUTO_CLEAR_SOURCE="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$IDLE_AUTO_CLEAR_SOURCE")/.." && pwd)"

# 環境変数で上書き可能なパス (テスト/別ツリー対応)
QUEUE_DIR="${AUTO_CLEAR_QUEUE_DIR:-$SCRIPT_DIR/queue}"
STATE_FILE="${AUTO_CLEAR_STATE_FILE:-$QUEUE_DIR/metrics/auto_clear_state.yaml}"
LOG_FILE="${AUTO_CLEAR_LOG_FILE:-$SCRIPT_DIR/logs/idle_auto_clear.log}"
IDLE_FLAG_DIR="${IDLE_FLAG_DIR:-/tmp}"

# Python (PyYAML) — inbox_write.sh と同じ venv を使う
PY="${AUTO_CLEAR_PYTHON:-$SCRIPT_DIR/.venv/bin/python3}"
[ -x "$PY" ] || PY="python3"

# agent registry (pane解決用)。関数定義のみで副作用なし。
# shellcheck source=lib/agent_registry.sh
if [ -f "$SCRIPT_DIR/lib/agent_registry.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/lib/agent_registry.sh"
fi

# ─────────────────────────────────────────────────────────────
# 既定値 (設計 §8)。env で事前設定済みなら尊重する。
#   安全側の既定: enabled=false (config 不在時に誤clearしない)
# ─────────────────────────────────────────────────────────────
: "${AUTO_CLEAR_ENABLED:=false}"
: "${AUTO_CLEAR_INTERVAL_SEC:=60}"
: "${AUTO_CLEAR_IDLE_GRACE_MIN:=15}"
: "${AUTO_CLEAR_BLOAT_IDLE_MIN:=30}"
: "${AUTO_CLEAR_COOLDOWN_MIN:=10}"
: "${AUTO_CLEAR_VERIFY_PANE:=false}"
: "${AUTO_CLEAR_FOOTER_HINT_ENABLED:=false}"
: "${AUTO_CLEAR_TOKEN_THRESHOLD_K:=0}"

# 配列既定値 (set -u 安全: ${var+x} は未設定でも安全)
if [ -z "${AUTO_CLEAR_TARGETS+x}" ]; then
    AUTO_CLEAR_TARGETS=(ashigaru1 ashigaru2 ashigaru3 ashigaru4 ashigaru5 ashigaru6 ashigaru7)
fi
if [ -z "${AUTO_CLEAR_FOOTER_HINT_PATTERNS+x}" ]; then
    AUTO_CLEAR_FOOTER_HINT_PATTERNS=()
fi

# 判定結果メッセージ用グローバル
REASON=""
TRIGGER=""

# ─────────────────────────────────────────────────────────────
# 小ヘルパ
# ─────────────────────────────────────────────────────────────

# ファイル mtime を epoch秒で返す (macOS: stat -f / Linux: stat -c)。失敗時0。
get_mtime() {
    local f="$1"
    stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0
}

# task YAML の status を返す。nested(task:)/flat 両対応。読めなければ空文字。
get_task_status() {
    local task="$1"
    [ -f "$task" ] || { echo ""; return 0; }
    TASK_PATH="$task" "$PY" - << 'PY' 2>/dev/null || echo ""
import os, sys, yaml
try:
    with open(os.environ["TASK_PATH"]) as f:
        d = yaml.safe_load(f) or {}
except Exception:
    print(""); sys.exit(0)
if isinstance(d, dict) and isinstance(d.get("task"), dict):
    t = d["task"]
elif isinstance(d, dict):
    t = d
else:
    t = {}
print(str(t.get("status") or "").strip())
PY
}

# inbox の未読(read: false)件数を返す。set -e 下で grep -c 0件→exit1 を握る (P7)。
get_unread_count() {
    local inbox="$1"
    local n
    n=$(grep -c 'read: false' "$inbox" 2>/dev/null || true)
    echo "${n:-0}"
}

# cooldown state から最終clearのepoch秒を返す。エントリ無し→0 (初回は必ず通過)。
state_get_last_clear() {
    local agent="$1"
    [ -f "$STATE_FILE" ] || { echo 0; return 0; }
    STATE_PATH="$STATE_FILE" STATE_AGENT="$agent" "$PY" - << 'PY' 2>/dev/null || echo 0
import os, sys, yaml
try:
    with open(os.environ["STATE_PATH"]) as f:
        d = yaml.safe_load(f) or {}
except Exception:
    print(0); sys.exit(0)
agents = (d.get("agents") or {}) if isinstance(d, dict) else {}
e = agents.get(os.environ["STATE_AGENT"]) or {}
try:
    print(int(e.get("last_clear_ts") or 0))
except Exception:
    print(0)
PY
}

# pane解決 (verify_pane / footer hint 時のみ使用)。
pane_for() {
    local agent="$1"
    local pane_base
    pane_base=$(tmux show-options -gv pane-base-index 2>/dev/null || echo 0)
    if command -v agent_registry_pane_for_agent >/dev/null 2>&1; then
        agent_registry_pane_for_agent "$agent" "$pane_base" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# ─────────────────────────────────────────────────────────────
# 安全判定 (誤clearゼロの中核・AND short-circuit・設計 §4.2)
#   戻り値: 0=安全(clear可) / 1=危険(clear不可)。$REASON に不成立理由をセット。
# ─────────────────────────────────────────────────────────────
is_safe_to_clear() {
    local agent="$1"
    local inbox="$QUEUE_DIR/inbox/${agent}.yaml"
    local task="$QUEUE_DIR/tasks/${agent}.yaml"
    local flag="${IDLE_FLAG_DIR:-/tmp}/shogun_idle_${agent}"
    local status unread now mtime idle_age last

    # (S1) task status ∈ {done, idle, failed} のみ許可。assigned/in_progress/blocked は即NG。
    status=$(get_task_status "$task")
    case "$status" in
        done|idle|failed) ;;
        *) REASON="status=${status:-empty}(working)"; return 1 ;;
    esac

    # (S2) inbox が存在し未読 = 0 (未処理メッセージがあるうちは clear 厳禁=メッセージ消失防止)。
    #      inbox不在/非数値は異常とみなし安全側=clearしない (fail-safe)。
    [ -f "$inbox" ] || { REASON="no-inbox"; return 1; }
    unread=$(get_unread_count "$inbox")
    if ! [[ "$unread" =~ ^[0-9]+$ ]] || [ "$unread" -ne 0 ]; then
        REASON="unread=$unread"; return 1
    fi

    # (S3) idle flag が存在する (claude CLI の非busyシグナル)。
    [ -f "$flag" ] || { REASON="no-idle-flag(busy)"; return 1; }

    # (S4) idle継続時間 >= idle_grace_min (turn開始直後の偽idleを除外)。
    now=$(date +%s)
    mtime=$(get_mtime "$flag")
    idle_age=$(( now - mtime ))
    if [ "$idle_age" -lt "$(( AUTO_CLEAR_IDLE_GRACE_MIN * 60 ))" ]; then
        REASON="idle_age=${idle_age}s<grace"; return 1
    fi

    # (S5) cooldown 経過 (同一足軽を cooldown_min 以内に再clearしない)。
    last=$(state_get_last_clear "$agent")
    if [ "$(( now - last ))" -lt "$(( AUTO_CLEAR_COOLDOWN_MIN * 60 ))" ]; then
        REASON="cooldown"; return 1
    fi

    # (S6) 任意・安全強化: capture-pane で生成中サイン("esc to")が無いことを二重確認。
    #      verify_pane=true のときのみ。pane取得失敗時は安全側=clearしない に倒す。
    if [ "${AUTO_CLEAR_VERIFY_PANE:-false}" = "true" ]; then
        local pane_out
        if ! pane_out=$(timeout 2 tmux capture-pane -t "$(pane_for "$agent")" -p 2>/dev/null); then
            REASON="pane-read-failed"; return 1
        fi
        pane_out=$(printf '%s\n' "$pane_out" | tail -5)
        if printf '%s\n' "$pane_out" | grep -qiF 'esc to'; then
            REASON="pane shows busy(esc to)"; return 1
        fi
    fi

    REASON=""; return 0
}

# ─────────────────────────────────────────────────────────────
# 肥大判定 (OR・主軸=idle継続時間・補助=footer hint・設計 §4.3)
#   戻り値: 0=肥大(clear候補) / 1=非肥大。$TRIGGER に成立トリガをセット。
# ─────────────────────────────────────────────────────────────
is_bloated() {
    local agent="$1"
    local flag="${IDLE_FLAG_DIR:-/tmp}/shogun_idle_${agent}"
    local now mtime idle_age

    # (T1・主軸) idle継続が bloat_idle_min を超過 → idle放置による肥大とみなす。
    now=$(date +%s)
    mtime=$(get_mtime "$flag")
    idle_age=$(( now - mtime ))
    if [ "$idle_age" -ge "$(( AUTO_CLEAR_BLOAT_IDLE_MIN * 60 ))" ]; then
        TRIGGER="idle_age=${idle_age}s>=bloat_idle_min"; return 0
    fi

    # (T2・補助) footer hint 検出。footer_hint_enabled=true のときのみ (実機文言確認まで false 固定)。
    if [ "${AUTO_CLEAR_FOOTER_HINT_ENABLED:-false}" = "true" ] \
       && [ "${#AUTO_CLEAR_FOOTER_HINT_PATTERNS[@]}" -gt 0 ]; then
        local pane_out pat
        if pane_out=$(timeout 2 tmux capture-pane -t "$(pane_for "$agent")" -p 2>/dev/null); then
            pane_out=$(printf '%s\n' "$pane_out" | tail -8)
            for pat in "${AUTO_CLEAR_FOOTER_HINT_PATTERNS[@]}"; do
                if printf '%s\n' "$pane_out" | grep -qiF "$pat"; then
                    TRIGGER="footer_hint:$pat"; return 0
                fi
            done
        fi
    fi

    TRIGGER=""; return 1
}

# ─────────────────────────────────────────────────────────────
# ログ (設計 §7: clear だけでなく skip 理由も全記録)
# ─────────────────────────────────────────────────────────────
log_line() {
    local kind="$1" agent="$2" detail="$3"
    local iso
    iso=$(date "+%Y-%m-%dT%H:%M:%S")
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    printf '[%s] [%s] agent=%s %s\n' "$iso" "$kind" "$agent" "$detail" >> "$LOG_FILE"
}
log_skip()  { log_line "SKIP"      "$1" "reason=$2"; }
log_clear() { log_line "CLEAR"     "$1" "trigger=$2"; }
log_dry()   { log_line "DRY-CLEAR" "$1" "trigger=$2"; }

# ─────────────────────────────────────────────────────────────
# 送出 (設計 §6: clear_command を inbox_write するだけ。tmuxは触らない)
# ─────────────────────────────────────────────────────────────
send_clear() {
    local agent="$1"
    bash "$SCRIPT_DIR/scripts/inbox_write.sh" "$agent" \
        "タスクYAMLを読んで作業開始せよ。" \
        clear_command idle_auto_clear
}

# cooldown state を flock(なければmkdirロック)付きで upsert (設計 §5)
record_clear() {
    local agent="$1" trigger="$2"
    local now iso lockdir i
    now=$(date +%s)
    iso=$(date "+%Y-%m-%dT%H:%M:%S")
    mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

    lockdir="${STATE_FILE}.lock.d"
    i=0
    while ! mkdir "$lockdir" 2>/dev/null; do
        sleep 0.1
        i=$((i + 1))
        [ "$i" -ge 50 ] && break   # 5s timeout — それでも upsert は試みる
    done

    STATE_PATH="$STATE_FILE" STATE_AGENT="$agent" STATE_TS="$now" \
    STATE_ISO="$iso" STATE_TRIG="$trigger" "$PY" - << 'PY' 2>/dev/null || true
import os, tempfile, yaml
sf = os.environ["STATE_PATH"]
agent = os.environ["STATE_AGENT"]
try:
    with open(sf) as f:
        d = yaml.safe_load(f) or {}
except Exception:
    d = {}
if not isinstance(d, dict):
    d = {}
agents = d.setdefault("agents", {})
if not isinstance(agents, dict):
    agents = d["agents"] = {}
e = agents.setdefault(agent, {})
if not isinstance(e, dict):
    e = agents[agent] = {}
e["last_clear_ts"] = int(os.environ["STATE_TS"])
e["last_clear_iso"] = os.environ["STATE_ISO"]
try:
    e["clear_count"] = int(e.get("clear_count") or 0) + 1
except Exception:
    e["clear_count"] = 1
e["last_trigger"] = os.environ["STATE_TRIG"]
fd, tmp = tempfile.mkstemp(dir=(os.path.dirname(sf) or "."), suffix=".tmp")
try:
    with os.fdopen(fd, "w") as f:
        yaml.dump(d, f, default_flow_style=False, allow_unicode=True, indent=2)
    os.replace(tmp, sf)
except Exception:
    try:
        os.unlink(tmp)
    except Exception:
        pass
    raise
PY

    rmdir "$lockdir" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────
# 1足軽の評価 → 条件成立時に clear (設計 §4.1)
# ─────────────────────────────────────────────────────────────
evaluate_and_maybe_clear() {
    local agent="$1"
    REASON=""; TRIGGER=""

    # 安全ゲート
    if ! is_safe_to_clear "$agent"; then
        log_skip "$agent" "$REASON"; return 0
    fi
    # 肥大トリガ
    if ! is_bloated "$agent"; then
        log_skip "$agent" "not-bloated"; return 0
    fi
    # 送出直前の double-check (判定〜送出間の状態変化を再確認・レース対策 P3/T18)
    if ! is_safe_to_clear "$agent"; then
        log_skip "$agent" "double-check-failed:$REASON"; return 0
    fi

    # dry-run: 送出せず判定だけ記録 (誤CLEAR判定の事前監査用)
    if [ "${DRY_RUN:-0}" = "1" ]; then
        log_dry "$agent" "$TRIGGER"; return 0
    fi

    if send_clear "$agent"; then
        record_clear "$agent" "$TRIGGER"
        log_clear "$agent" "$TRIGGER"
    else
        log_skip "$agent" "send-failed"
    fi
}

# ─────────────────────────────────────────────────────────────
# 全足軽スキャン
# ─────────────────────────────────────────────────────────────
scan_all_targets() {
    # 全体OFFスイッチ (緊急停止 P8)。dry-run時は判定観測のため enabled を無視。
    if [ "${DRY_RUN:-0}" != "1" ] && [ "${AUTO_CLEAR_ENABLED:-false}" != "true" ]; then
        return 0
    fi
    # 空 targets (設定漏れ等) では何もしない。set -u 下の unbound 配列展開クラッシュも回避。
    [ "${#AUTO_CLEAR_TARGETS[@]}" -gt 0 ] || return 0
    local agent
    for agent in "${AUTO_CLEAR_TARGETS[@]}"; do
        evaluate_and_maybe_clear "$agent"
    done
}

# ─────────────────────────────────────────────────────────────
# config loader (設計 §8: settings.yaml auto_clear ブロック)
# ─────────────────────────────────────────────────────────────
load_config() {
    local settings="${AUTO_CLEAR_SETTINGS:-$SCRIPT_DIR/config/settings.yaml}"
    [ -f "$settings" ] || return 0
    local out
    out=$(SETTINGS_PATH="$settings" "$PY" - << 'PY' 2>/dev/null || true
import os, yaml
try:
    with open(os.environ["SETTINGS_PATH"]) as f:
        d = yaml.safe_load(f) or {}
except Exception:
    d = {}
ac = (d.get("auto_clear") or {}) if isinstance(d, dict) else {}
if not isinstance(ac, dict):
    ac = {}
def b(v):
    return "true" if v else "false"
def i(v, dflt):
    try:
        return int(v)
    except Exception:
        return dflt
print("AUTO_CLEAR_ENABLED=%s" % b(ac.get("enabled", False)))
print("AUTO_CLEAR_INTERVAL_SEC=%d" % i(ac.get("interval_sec", 60), 60))
print("AUTO_CLEAR_IDLE_GRACE_MIN=%d" % i(ac.get("idle_grace_min", 15), 15))
print("AUTO_CLEAR_BLOAT_IDLE_MIN=%d" % i(ac.get("bloat_idle_min", 30), 30))
print("AUTO_CLEAR_COOLDOWN_MIN=%d" % i(ac.get("cooldown_min", 10), 10))
print("AUTO_CLEAR_VERIFY_PANE=%s" % b(ac.get("verify_pane", False)))
print("AUTO_CLEAR_FOOTER_HINT_ENABLED=%s" % b(ac.get("footer_hint_enabled", False)))
print("AUTO_CLEAR_TOKEN_THRESHOLD_K=%d" % i(ac.get("token_threshold_k", 0), 0))
targets = ac.get("targets") or []
if not isinstance(targets, list):
    targets = []
def shq(s):
    return "'" + str(s).replace("'", "'\\''") + "'"
print("AUTO_CLEAR_TARGETS=(%s)" % " ".join(shq(t) for t in targets))
pats = ac.get("footer_hint_patterns") or []
if not isinstance(pats, list):
    pats = []
print("AUTO_CLEAR_FOOTER_HINT_PATTERNS=(%s)" % " ".join(shq(p) for p in pats))
PY
)
    [ -n "$out" ] && eval "$out"
    # targets が空(設定漏れ)なら安全側で何もしない既定に倒す
    if [ "${#AUTO_CLEAR_TARGETS[@]}" -eq 0 ]; then
        AUTO_CLEAR_TARGETS=(ashigaru1 ashigaru2 ashigaru3 ashigaru4 ashigaru5 ashigaru6 ashigaru7)
    fi
}

# ─────────────────────────────────────────────────────────────
# main
# ─────────────────────────────────────────────────────────────
main() {
    local once=0
    DRY_RUN="${DRY_RUN:-0}"
    while [ $# -gt 0 ]; do
        case "$1" in
            --once)    once=1 ;;
            --dry-run) DRY_RUN=1 ;;
            *) ;;
        esac
        shift
    done

    load_config

    if [ "$once" = "1" ]; then
        scan_all_targets
        return 0
    fi

    while true; do
        load_config            # 毎サイクル再読込: enabled=false の即時反映 (緊急停止 P8)
        scan_all_targets
        sleep "${AUTO_CLEAR_INTERVAL_SEC:-60}"
    done
}

# テスト時 (__IDLE_AUTO_CLEAR_TESTING__=1) は main を実行しない (関数のみ提供)
if [ "${__IDLE_AUTO_CLEAR_TESTING__:-0}" != "1" ]; then
    main "$@"
fi
