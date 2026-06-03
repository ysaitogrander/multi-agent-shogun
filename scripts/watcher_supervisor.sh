#!/usr/bin/env bash
set -euo pipefail

# Keep inbox watchers alive in a persistent tmux-hosted shell.
# This script is designed to run forever.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

mkdir -p logs queue/inbox

# W4: Get all agents present in the multiagent window via live @agent_id metadata.
# Returns one agent name per line; skips panes with no @agent_id set.
# This replaces the static settings-order registry, eliminating off-by-one misrouting.
live_multiagent_agents() {
    tmux list-panes -t multiagent -F '#{@agent_id}' 2>/dev/null \
        | grep -v '^$'
}

# W4: Resolve the tmux pane address for an agent by querying @agent_id at runtime.
# Avoids dependency on settings order; returns 1 if the agent is not found in the window.
resolve_pane_by_agent_id() {
    local agent="$1"
    local pane_idx
    pane_idx=$(tmux list-panes -t multiagent -F '#{pane_index} #{@agent_id}' 2>/dev/null \
        | awk -v a="$agent" '$2 == a { print $1; exit }')
    [ -n "$pane_idx" ] || return 1
    printf 'multiagent:agents.%s\n' "$pane_idx"
}

ensure_inbox_file() {
    local agent="$1"
    if [ ! -f "queue/inbox/${agent}.yaml" ]; then
        printf 'messages: []\n' > "queue/inbox/${agent}.yaml"
    fi
}

pane_exists() {
    local pane="$1"
    tmux list-panes -a -F "#{session_name}:#{window_name}.#{pane_index}" 2>/dev/null | grep -qx "$pane"
}

start_watcher_if_missing() {
    local agent="$1"
    local pane="$2"
    local log_file="$3"
    local cli

    ensure_inbox_file "$agent"
    if ! pane_exists "$pane"; then
        return 0
    fi

    if pgrep -f "scripts/inbox_watcher.sh ${agent} ${pane}( |$)" >/dev/null 2>&1; then
        return 0
    fi

    if pgrep -f "scripts/inbox_watcher.sh ${agent} " >/dev/null 2>&1; then
        echo "[$(date)] [WARN] stale watcher detected for ${agent}; starting watcher for expected pane ${pane}" >&2
    fi

    cli=$(tmux show-options -p -t "$pane" -v @agent_cli 2>/dev/null || echo "codex")
    nohup bash scripts/inbox_watcher.sh "$agent" "$pane" "$cli" >> "$log_file" 2>&1 &
}

# W4: Build watcher specs from live tmux @agent_id metadata instead of static registry.
# Each cycle re-queries tmux so pane layout changes are picked up automatically.
watcher_specs() {
    local agent pane
    while IFS= read -r agent; do
        [ -z "$agent" ] && continue
        if ! pane=$(resolve_pane_by_agent_id "$agent"); then
            continue
        fi
        printf '%s\t%s\tlogs/inbox_watcher_%s.log\n' "$agent" "$pane" "$agent"
    done < <(live_multiagent_agents)
}

start_all_watchers() {
    local agent pane log_file
    while IFS=$'\t' read -r agent pane log_file; do
        start_watcher_if_missing "$agent" "$pane" "$log_file"
    done < <(watcher_specs)
}

# idle足軽 自動/clear デーモン (cmd_585)。不在なら起動する。
# idle_auto_clear.sh は判定専用で tmux を触らず、clear_command を inbox_write するのみ。
start_auto_clear_if_missing() {
    if [ ! -f "$SCRIPT_DIR/scripts/idle_auto_clear.sh" ]; then
        return 0
    fi
    if pgrep -f "scripts/idle_auto_clear.sh" >/dev/null 2>&1; then
        return 0
    fi
    nohup bash scripts/idle_auto_clear.sh >> logs/idle_auto_clear.log 2>&1 &
}

# dashboard.md 🚨要対応 新規項目通知デーモン (cmd_643)
start_action_notifier_if_missing() {
    if [ ! -f "$SCRIPT_DIR/scripts/action_required_notifier.sh" ]; then
        return 0
    fi
    if pgrep -f "scripts/action_required_notifier.sh" >/dev/null 2>&1; then
        return 0
    fi
    nohup bash scripts/action_required_notifier.sh >> logs/action_required_notifier.log 2>&1 &
}

# fleet_watchdog.sh 常駐化 (cmd_706 U2)
# enabled=false fail-safe は fleet_watchdog.sh 側で制御するためここでは起動するだけ。
start_fleet_watchdog_if_missing() {
    if [ ! -f "$SCRIPT_DIR/scripts/fleet_watchdog.sh" ]; then
        return 0
    fi
    if pgrep -f "scripts/fleet_watchdog.sh" >/dev/null 2>&1; then
        return 0
    fi
    nohup bash scripts/fleet_watchdog.sh >> logs/fleet_watchdog.log 2>&1 &
}

if [ "${1:-}" = "--print-watchers" ]; then
    watcher_specs
    printf 'fleet_watchdog\t(managed-daemon)\tlogs/fleet_watchdog.log\n'
    exit 0
fi

while true; do
    start_all_watchers
    start_auto_clear_if_missing
    start_action_notifier_if_missing
    start_fleet_watchdog_if_missing
    sleep 5
done
