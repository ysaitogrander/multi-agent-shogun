#!/usr/bin/env bash
# scripts/copilot_watcher.sh — Copilot agent watcher
# Polls ashigaru_copilot.yaml mtime and spawns copilot --yolo -p on new task_id.
#
# Design requirements R1-R5:
#   R1: Single instance via PID file + flock. State file deduplicates task_ids.
#   R2: Each task_id spawned at most once (state file). Settle wait = debounce.
#   R3: Never interpolate task content into -p string. Fixed prompt + task_id only.
#   R4: Read YAML only after mtime is stable (avoid partial-write spawn).
#   R5: Re-validate via lib/copilot_safety.sh validate_command before every spawn.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ─── 定数 ───────────────────────────────────────────────────────────────────
TASK_YAML="$SCRIPT_DIR/queue/tasks/ashigaru_copilot.yaml"
STATE_DIR="$SCRIPT_DIR/queue/state"
STATE_FILE="$STATE_DIR/copilot_processed.txt"
PID_FILE="/tmp/copilot_watcher.pid"
LOCK_FILE="/tmp/copilot_watcher.lock"
LOG_FILE="$SCRIPT_DIR/logs/copilot_watcher.log"
SAFETY_LIB="$SCRIPT_DIR/lib/copilot_safety.sh"
AGMSG_SEND="$HOME/.agents/skills/agmsg/scripts/send.sh"
AGMSG_TEAM="shogun"

POLL_SEC=5
SETTLE_SEC=2

# ─── 単一インスタンス保証 (R1) ───────────────────────────────────────────────
# flockが利用可能ならflockを使い、なければPIDファイルで判定する。
exec 200>"$LOCK_FILE"
if ! flock -n 200 2>/dev/null; then
    existing_pid=""
    if [ -f "$PID_FILE" ]; then
        existing_pid=$(cat "$PID_FILE" 2>/dev/null || true)
    fi
    if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
        echo "[copilot_watcher] Already running (PID=$existing_pid). Exit." >&2
        exit 0
    fi
fi
echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE" "$LOCK_FILE"' EXIT

# ─── ログ初期化 ──────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$LOG_FILE")" "$STATE_DIR"
log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] $*" | tee -a "$LOG_FILE" >&2
}

log "copilot_watcher started (PID=$$)"

# ─── 安全ライブラリ読み込み ──────────────────────────────────────────────────
if [ -f "$SAFETY_LIB" ]; then
    source "$SAFETY_LIB"
else
    log "ERROR: lib/copilot_safety.sh not found. Cannot start safely."
    exit 1
fi

# ─── mtime取得 (macOS/Linux両対応) ──────────────────────────────────────────
get_mtime() {
    stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# ─── 処理済みtask_id確認 (R1) ────────────────────────────────────────────────
is_processed() {
    local task_id="$1"
    [ -f "$STATE_FILE" ] && grep -qxF "$task_id" "$STATE_FILE" 2>/dev/null
}

mark_processed() {
    local task_id="$1"
    echo "$task_id" >> "$STATE_FILE"
    log "Marked processed: $task_id"
}

# ─── YAML フィールド取得 (python3使用) ───────────────────────────────────────
parse_yaml_field() {
    local file="$1"
    local field="$2"
    python3 - <<PY
import yaml, sys
try:
    with open("$file") as f:
        data = yaml.safe_load(f) or {}
    val = data.get("$field", "")
    print(str(val).strip() if val else "")
except Exception as e:
    sys.exit(0)
PY
}

# ─── 報告 (宛先別経路分岐) ───────────────────────────────────────────────────
# gunshi/karo は agmsg 未参加 → file-inbox(inbox_write.sh) 経由
# shogun 等 agmsg メンバー → 従来の agmsg 経路
report() {
    local to="$1"
    local msg="$2"
    local inbox_write="$SCRIPT_DIR/scripts/inbox_write.sh"
    if [[ "$to" == "gunshi" || "$to" == "karo" ]]; then
        if [ -f "$inbox_write" ]; then
            bash "$inbox_write" "$to" "$msg" report_received copilot_watcher 2>/dev/null \
                || log "WARN: inbox_write.sh failed for $to"
        else
            log "WARN: inbox_write.sh not found, cannot report to $to"
        fi
    else
        if [ -f "$AGMSG_SEND" ]; then
            bash "$AGMSG_SEND" "$AGMSG_TEAM" "copilot_watcher" "$to" "$msg" 2>/dev/null \
                || log "WARN: agmsg send.sh failed for $to"
        else
            log "WARN: agmsg send.sh not found, cannot report to $to"
        fi
    fi
}

# ─── メインwatch関数 ─────────────────────────────────────────────────────────
run_watcher() {
    local last_mtime=0

    log "Polling $TASK_YAML every ${POLL_SEC}s..."

    while true; do
        sleep "$POLL_SEC"

        # YAMLが存在しなければスキップ
        [ -f "$TASK_YAML" ] || continue

        # mtime変化確認 (R4: 更新検知)
        local mtime1
        mtime1=$(get_mtime "$TASK_YAML")
        if [ "$mtime1" = "$last_mtime" ]; then
            continue
        fi

        # R4: settle待機 (部分書込中を避ける)
        sleep "$SETTLE_SEC"
        local mtime2
        mtime2=$(get_mtime "$TASK_YAML")
        if [ "$mtime1" != "$mtime2" ]; then
            log "mtime still changing (settle未完了), skip cycle"
            continue
        fi

        # YAMLが安定した → 更新済み
        last_mtime="$mtime2"

        # YAML読み込み
        local task_id task_status task_command
        task_id=$(parse_yaml_field "$TASK_YAML" "task_id")
        task_status=$(parse_yaml_field "$TASK_YAML" "status")
        task_command=$(parse_yaml_field "$TASK_YAML" "command")

        [ -z "$task_id" ] && continue

        # statusがworkでなければスキップ
        if [ "$task_status" != "work" ]; then
            log "task_id=$task_id status=$task_status (not work), skip"
            continue
        fi

        # R1/R2: 処理済みtask_idはspawnしない
        if is_processed "$task_id"; then
            log "[SKIP] task_id=$task_id already in state file (dedup)"
            continue
        fi

        log "New task detected: task_id=$task_id status=$task_status"

        # R5: spawn直前にvalidate_command (防御二重化)
        if [ -n "$task_command" ]; then
            local validate_output
            if ! validate_output=$(validate_command "$task_command" 2>&1); then
                log "[BLOCKED] validate_command FAILED for task_id=$task_id"
                log "$validate_output"
                mark_processed "$task_id"  # 再spawn抑止
                report "gunshi" "[copilot_watcher] BLOCKED: task_id=${task_id} — validate_command BAN検知。spawnを中止。詳細: ${validate_output}"
                report "karo"   "[copilot_watcher] BLOCKED: task_id=${task_id} — validate_command BAN検知。spawnを中止。"
                continue
            fi
            warn_external_api "$task_command" 2>&1 | while IFS= read -r line; do log "$line"; done || true
        fi

        # R3: 固定promptファイル経由でcopilotに渡す (task全文interpolate禁止)
        local prompt_file="/tmp/copilot_watcher_prompt_$$.txt"
        printf '%s' "queue/tasks/ashigaru_copilot.yaml と queue/inbox/ashigaru_copilot.yaml を読んで割り当てタスクを実行せよ。task_id: ${task_id}" > "$prompt_file"

        # R1: spawnより先に処理済み記録 (二重spawn防止)
        mark_processed "$task_id"

        log "Spawning: copilot --yolo -p '...(fixed prompt)...' for task_id=$task_id"

        # spawn実行 (set -e は一時解除して終了コード取得)
        local exit_code=0
        set +e
        copilot --yolo -p "$(cat "$prompt_file")" >> "$LOG_FILE" 2>&1
        exit_code=$?
        set -e
        rm -f "$prompt_file"

        log "copilot exited exit_code=$exit_code for task_id=$task_id"

        # 完走後agmsg報告
        if [ "$exit_code" -eq 0 ]; then
            report "gunshi" "[copilot_watcher] task_id=${task_id} 完走(exit=0)。Copilotワンショット実行完了。"
            report "karo"   "[copilot_watcher] task_id=${task_id} 完走(exit=0)。Copilotワンショット実行完了。"
        else
            report "gunshi" "[copilot_watcher] task_id=${task_id} 異常終了(exit=${exit_code})。確認を仰ぎたし。"
            report "karo"   "[copilot_watcher] task_id=${task_id} 異常終了(exit=${exit_code})。確認を仰ぎたし。"
        fi
    done
}

# ─── 自己再起動ループ (クラッシュ時自動復活) ─────────────────────────────────
while true; do
    run_watcher || true
    log "WARN: run_watcher exited unexpectedly. Restarting in 10s..."
    sleep 10
done
