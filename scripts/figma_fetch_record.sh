#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# figma_fetch_record.sh — Record Figma fetch evidence
# ═══════════════════════════════════════════════════════════════
# Call this immediately after fetching Figma node data via
# mcp__figma__view_node to record evidence for figma-fresh-fetch-guard.
#
# Usage:
#   bash scripts/figma_fetch_record.sh <node_id> [description] [--url <figma_url>] [--scope <file_paths>]
#
# Examples (backward-compatible):
#   bash scripts/figma_fetch_record.sh "4560-89033" "タブレット正典xDQ4U取得"
#   bash scripts/figma_fetch_record.sh "1234-5678"
#
# Examples (extended with url + scope):
#   bash scripts/figma_fetch_record.sh "4560-89033" "正典取得" \
#     --url "https://www.figma.com/file/xDQ4U.../..." \
#     --scope "resources/views/tablet/index.blade.php"
#
# Output format (new — extended):
#   <ISO8601> node:<id> url:<url> scope:<paths> by:<agent> [desc]
#
# Output format (old — backward-compatible, when --url/--scope omitted):
#   <ISO8601> node:<id> by:<agent> [desc]
#
# Both formats are readable by lib/figma_guard_common.sh::has_fresh_evidence.
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_LOG="$SCRIPT_DIR/logs/figma_fetch_evidence.log"

# ─── Args (backward-compatible positional + optional named flags) ───
NODE_ID="${1:-}"
if [ -z "$NODE_ID" ]; then
    echo "Usage: bash scripts/figma_fetch_record.sh <node_id> [description] [--url <url>] [--scope <paths>]" >&2
    exit 1
fi
shift

DESCRIPTION=""
URL=""
SCOPE=""

# Second positional arg (if not a flag) is description — backward compat
if [ $# -gt 0 ] && [[ "${1:-}" != --* ]]; then
    DESCRIPTION="$1"
    shift
fi

# Parse remaining named flags
while [ $# -gt 0 ]; do
    case "${1:-}" in
        --url)   URL="${2:-}";   shift 2 ;;
        --scope) SCOPE="${2:-}"; shift 2 ;;
        --desc)  DESCRIPTION="${2:-}"; shift 2 ;;
        *) shift ;;
    esac
done

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
# New format (when url/scope provided): <ISO8601> node:<id> url:<url> scope:<paths> by:<agent> [desc]
# Old format (backward compat):         <ISO8601> node:<id> by:<agent> [desc]
TIMESTAMP=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
RECORD="${TIMESTAMP} node:${NODE_ID}"
[ -n "$URL" ]   && RECORD="${RECORD} url:${URL}"
[ -n "$SCOPE" ] && RECORD="${RECORD} scope:${SCOPE}"
RECORD="${RECORD} by:${AGENT_ID}"
[ -n "$DESCRIPTION" ] && RECORD="${RECORD} ${DESCRIPTION}"

# ─── Append to evidence log ───
echo "$RECORD" >> "$EVIDENCE_LOG"

echo "[figma-fetch-record] Recorded: $RECORD"
echo "[figma-fetch-record] Evidence log: $EVIDENCE_LOG"
