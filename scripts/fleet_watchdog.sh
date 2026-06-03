#!/usr/bin/env bash
# fleet_watchdog.sh — karo停止検知・再nudge番犬 (cmd_706 U1)
#
# 役割:
#   - idle状態でinbox未読を抱えたkaro(家老)を検出し、inbox_writeで再nudgeするだけ。
#   - tmux send-keys は一切触らない (配達層=inbox_watcher に委譲)。
#   - karo専任。clear・spawn・kill は絶対に行わない (W5・D006)。
#
# 安全保証:
#   W1: /tmp/shogun_idle_karo + mtime >= idle_grace_min でidle判定
#       (capture-pane ❯末尾検知は補助のみ — 主根拠にしない)
#   W2: queue/inbox/karo.yaml の read:false>0 を必須主軸 + 送出直前 double-check
#   W3: cooldown state file で連打防止 (同一起床の再nudge連発を排除)
#   W5: 対象=karo限定・動作=再nudge限定
#   fail-safe: enabled=false 既定 (config不在でも誤介入しない)
#
# テスト容易性:
#   __FLEET_WATCHDOG_TESTING__=1 で source すると main を実行しない。
#   WATCHDOG_* 環境変数でパスを上書き可能。

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# パス基準
# ─────────────────────────────────────────────────────────────
FLEET_WATCHDOG_SOURCE="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$FLEET_WATCHDOG_SOURCE")/.." && pwd)"

QUEUE_DIR="${WATCHDOG_QUEUE_DIR:-$SCRIPT_DIR/queue}"
STATE_FILE="${WATCHDOG_STATE_FILE:-$QUEUE_DIR/metrics/fleet_watchdog_state.yaml}"
LOG_FILE="${WATCHDOG_LOG_FILE:-$SCRIPT_DIR/logs/fleet_watchdog.log}"
IDLE_FLAG_DIR="${IDLE_FLAG_DIR:-/tmp}"

PY="${WATCHDOG_PYTHON:-$SCRIPT_DIR/.venv/bin/python3}"
[ -x "$PY" ] || PY="python3"

# ─────────────────────────────────────────────────────────────
# 既定値 (enabled=false が fail-safe)
# ─────────────────────────────────────────────────────────────
: "${WATCHDOG_ENABLED:=false}"
: "${WATCHDOG_INTERVAL_SEC:=30}"
: "${WATCHDOG_IDLE_GRACE_MIN:=10}"
: "${WATCHDOG_COOLDOWN_MIN:=5}"
: "${WATCHDOG_TARGET:=karo}"

REASON=""

# ─────────────────────────────────────────────────────────────
# 小ヘルパ
# ─────────────────────────────────────────────────────────────

# ファイル mtime を epoch秒で返す (macOS: stat -f / Linux: stat -c)。失敗時0。
get_mtime() {
    local f="$1"
    stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0
}

# inbox の未読(read: false)件数を返す。grep 0件→exit1 を握る。
get_unread_count() {
    local inbox="$1"
    local n
    n=$(grep -c 'read: false' "$inbox" 2>/dev/null || true)
    echo "${n:-0}"
}

# cooldown state から最終nudgeのepoch秒を返す。エントリ無し→0 (初回は必ず通過)。
state_get_last_nudge() {
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
    print(int(e.get("last_nudge_ts") or 0))
except Exception:
    print(0)
PY
}

# ─────────────────────────────────────────────────────────────
# 介入判定 (AND short-circuit)
#   戻り値: 0=介入すべき / 1=スキップ。$REASON に不成立理由をセット。
# ─────────────────────────────────────────────────────────────
should_nudge() {
    local agent="$1"
    local inbox="$QUEUE_DIR/inbox/${agent}.yaml"
    local flag="${IDLE_FLAG_DIR}/shogun_idle_${agent}"
    local unread now mtime idle_age last

    # (C1) W1: idle flag 存在確認 (inbox_watcher が非busyシグナル時に設置)
    [ -f "$flag" ] || { REASON="no-idle-flag(busy)"; return 1; }

    # (C2) W1: idle継続時間 >= idle_grace_min (turn直後の偽idleを除外)
    now=$(date +%s)
    mtime=$(get_mtime "$flag")
    idle_age=$(( now - mtime ))
    if [ "$idle_age" -lt "$(( WATCHDOG_IDLE_GRACE_MIN * 60 ))" ]; then
        REASON="idle_age=${idle_age}s<grace($(( WATCHDOG_IDLE_GRACE_MIN * 60 ))s)"; return 1
    fi

    # (C3) W2: inbox が存在し未読(read:false)>0 — 必須主軸条件
    [ -f "$inbox" ] || { REASON="no-inbox"; return 1; }
    unread=$(get_unread_count "$inbox")
    if ! [[ "$unread" =~ ^[0-9]+$ ]] || [ "$unread" -eq 0 ]; then
        REASON="unread=${unread}(no-pending)"; return 1
    fi

    # (C4) W3: cooldown 経過確認
    last=$(state_get_last_nudge "$agent")
    if [ "$(( now - last ))" -lt "$(( WATCHDOG_COOLDOWN_MIN * 60 ))" ]; then
        REASON="cooldown"; return 1
    fi

    REASON=""; return 0
}

# ─────────────────────────────────────────────────────────────
# ログ (全skip理由も記録)
# ─────────────────────────────────────────────────────────────
log_line() {
    local kind="$1" agent="$2" detail="$3"
    local iso
    iso=$(date "+%Y-%m-%dT%H:%M:%S")
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    printf '[%s] [%s] agent=%s %s\n' "$iso" "$kind" "$agent" "$detail" >> "$LOG_FILE"
}
log_skip()  { log_line "SKIP"      "$1" "reason=$2"; }
log_nudge() { log_line "NUDGE"     "$1" "unread=$2"; }
log_dry()   { log_line "DRY-NUDGE" "$1" "unread=$2"; }

# ─────────────────────────────────────────────────────────────
# 送出 (W5: inbox_write による配達層再トリガのみ。tmux非接触)
# ─────────────────────────────────────────────────────────────
send_nudge() {
    local agent="$1"
    bash "$SCRIPT_DIR/scripts/inbox_write.sh" "$agent" \
        "inbox未読あり。タスクYAMLを読んで処理せよ。" \
        nudge fleet_watchdog
}

# cooldown state を flock付きで upsert
record_nudge() {
    local agent="$1"
    local now iso lockdir i
    now=$(date +%s)
    iso=$(date "+%Y-%m-%dT%H:%M:%S")
    mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

    lockdir="${STATE_FILE}.lock.d"
    i=0
    while ! mkdir "$lockdir" 2>/dev/null; do
        sleep 0.1
        i=$((i + 1))
        [ "$i" -ge 50 ] && break
    done

    STATE_PATH="$STATE_FILE" STATE_AGENT="$agent" STATE_TS="$now" \
    STATE_ISO="$iso" "$PY" - << 'PY' 2>/dev/null || true
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
e["last_nudge_ts"] = int(os.environ["STATE_TS"])
e["last_nudge_iso"] = os.environ["STATE_ISO"]
try:
    e["nudge_count"] = int(e.get("nudge_count") or 0) + 1
except Exception:
    e["nudge_count"] = 1
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
# karo評価 → 条件成立時に再nudge
# ─────────────────────────────────────────────────────────────
evaluate_and_maybe_nudge() {
    local agent="${WATCHDOG_TARGET:-karo}"
    local inbox="$QUEUE_DIR/inbox/${agent}.yaml"
    REASON=""

    # 介入条件確認 (AND short-circuit)
    if ! should_nudge "$agent"; then
        log_skip "$agent" "$REASON"; return 0
    fi

    # unread取得 (ログ用)
    local unread
    unread=$(get_unread_count "$inbox")

    # 送出直前の double-check (W2: race対策)
    if ! should_nudge "$agent"; then
        log_skip "$agent" "double-check-failed:$REASON"; return 0
    fi

    if [ "${DRY_RUN:-0}" = "1" ]; then
        log_dry "$agent" "$unread"; return 0
    fi

    if send_nudge "$agent"; then
        record_nudge "$agent"
        log_nudge "$agent" "$unread"
    else
        log_skip "$agent" "send-failed"
    fi
}

# ─────────────────────────────────────────────────────────────
# config loader (settings.yaml fleet_watchdog ブロック)
# ─────────────────────────────────────────────────────────────
load_config() {
    local settings="${WATCHDOG_SETTINGS:-$SCRIPT_DIR/config/settings.yaml}"
    [ -f "$settings" ] || return 0
    local out
    out=$(SETTINGS_PATH="$settings" "$PY" - << 'PY' 2>/dev/null || true
import os, yaml
try:
    with open(os.environ["SETTINGS_PATH"]) as f:
        d = yaml.safe_load(f) or {}
except Exception:
    d = {}
fw = (d.get("fleet_watchdog") or {}) if isinstance(d, dict) else {}
if not isinstance(fw, dict):
    fw = {}
def b(v):
    return "true" if v else "false"
def i(v, dflt):
    try:
        return int(v)
    except Exception:
        return dflt
def s(v, dflt):
    return str(v) if v else dflt
print("WATCHDOG_ENABLED=%s"       % b(fw.get("enabled",         False)))
print("WATCHDOG_INTERVAL_SEC=%d"  % i(fw.get("interval_sec",    30),  30))
print("WATCHDOG_IDLE_GRACE_MIN=%d"% i(fw.get("idle_grace_min",  10),  10))
print("WATCHDOG_COOLDOWN_MIN=%d"  % i(fw.get("cooldown_min",     5),   5))
print("WATCHDOG_TARGET=%s"        % s(fw.get("target"),          "karo"))
PY
)
    [ -n "$out" ] && eval "$out"
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
        if [ "${DRY_RUN:-0}" != "1" ] && [ "${WATCHDOG_ENABLED:-false}" != "true" ]; then
            return 0
        fi
        evaluate_and_maybe_nudge
        return 0
    fi

    while true; do
        load_config  # 毎サイクル再読込: enabled=false の即時反映 (緊急停止)
        if [ "${WATCHDOG_ENABLED:-false}" = "true" ] || [ "${DRY_RUN:-0}" = "1" ]; then
            evaluate_and_maybe_nudge
        fi
        sleep "${WATCHDOG_INTERVAL_SEC:-30}"
    done
}

# テスト時は main を実行しない (関数のみ提供)
if [ "${__FLEET_WATCHDOG_TESTING__:-0}" != "1" ]; then
    main "$@"
fi
