#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# figma_fetch_record.sh — Record Figma fetch evidence
# ═══════════════════════════════════════════════════════════════
# Call this immediately after fetching Figma node data via
# mcp__figma__view_node to record evidence for figma-fresh-fetch-guard.
#
# Usage:
#   bash scripts/figma_fetch_record.sh <node_id> [description]
#
# Examples:
#   bash scripts/figma_fetch_record.sh "4560-89033" "タブレット正典xDQ4U取得"
#   bash scripts/figma_fetch_record.sh "1234-5678"
#
# Output: Appends one line to logs/figma_fetch_evidence.log:
#   2026-06-03T16:30:00+09:00 node:4560-89033 by:ashigaru2 タブレット正典xDQ4U取得
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_LOG="$SCRIPT_DIR/logs/figma_fetch_evidence.log"

# ─── Args ───
NODE_ID="${1:-}"
DESCRIPTION="${2:-}"

if [ -z "$NODE_ID" ]; then
    echo "Usage: bash scripts/figma_fetch_record.sh <node_id> [description]" >&2
    exit 1
fi

# ─── Identify agent ───
AGENT_ID=""
if [ -n "${TMUX_PANE:-}" ]; then
    AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || true)
fi
if [ -z "$AGENT_ID" ]; then
    AGENT_ID="${USER:-unknown}"
fi

# ─── Ensure logs dir exists ───
mkdir -p "$SCRIPT_DIR/logs"

# ─── Build record line ───
TIMESTAMP=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
RECORD="${TIMESTAMP} node:${NODE_ID} by:${AGENT_ID}"
if [ -n "$DESCRIPTION" ]; then
    RECORD="${RECORD} ${DESCRIPTION}"
fi

# ─── Append to evidence log ───
echo "$RECORD" >> "$EVIDENCE_LOG"

echo "[figma-fetch-record] Recorded: $RECORD"
echo "[figma-fetch-record] Evidence log: $EVIDENCE_LOG"
