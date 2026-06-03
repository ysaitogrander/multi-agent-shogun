#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# figma_fresh_fetch_guard.sh — Pre-PR hook: 48h Figma evidence gate
# ═══════════════════════════════════════════════════════════════
# Registered as a PreToolUse hook (Bash matcher) in .claude/settings.json.
# Blocks `gh pr create` when no Figma fetch evidence within 48h exists.
#
# Input  (stdin): JSON with tool_name + tool_input.command
# Output (stdout): {"decision":"block","reason":"..."} to block,
#                  or nothing (exit 0) to approve.
#
# Evidence file: logs/figma_fetch_evidence.log
#   Format per line: <ISO8601> node:<node_id> by:<agent_id> [<description>]
#   Written by: scripts/figma_fetch_record.sh
#
# Canonical Figma map: context/figma-canonical-map.md (read-only reference)
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_LOG="$SCRIPT_DIR/logs/figma_fetch_evidence.log"
BYPASS_FILE="$SCRIPT_DIR/.figma-guard-bypass"
THRESHOLD_HOURS=48

# ─── Read hook input ───
INPUT=$(cat)

# ─── Extract tool_name and command ───
TOOL_NAME=$(echo "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" \
    2>/dev/null || echo "")
COMMAND=$(echo "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" \
    2>/dev/null || echo "")

# ─── Only intercept Bash tool ───
if [ "$TOOL_NAME" != "Bash" ]; then
    exit 0
fi

# ─── Only intercept gh pr create / gh pr new ───
if ! echo "$COMMAND" | grep -qE 'gh[[:space:]]+(pr[[:space:]]+(create|new)|pr[[:space:]]+create)'; then
    exit 0
fi

# ─── Bypass file check (shogun-authorized emergency skip) ───
if [ -f "$BYPASS_FILE" ]; then
    BYPASS_REASON=$(cat "$BYPASS_FILE" 2>/dev/null || echo "bypass authorized")
    echo "[figma-fresh-fetch-guard] BYPASS active: $BYPASS_REASON" >&2
    exit 0
fi

# ─── Check Figma fetch evidence within threshold ───
THRESHOLD_SECONDS=$((THRESHOLD_HOURS * 3600))

FOUND_FRESH=0
FRESH_LINE=""

if [ -f "$EVIDENCE_LOG" ] && [ -s "$EVIDENCE_LOG" ]; then
    while IFS= read -r line; do
        # Skip blank lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue

        TS_STR=$(echo "$line" | awk '{print $1}')
        [ -z "$TS_STR" ] && continue

        ENTRY_EPOCH=$(python3 -c "
import sys
from datetime import datetime, timezone
ts = '$TS_STR'
try:
    dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    print(int(dt.timestamp()))
except Exception as e:
    print(0)
" 2>/dev/null || echo "0")

        CURRENT_EPOCH=$(date +%s)
        DIFF=$(( CURRENT_EPOCH - ENTRY_EPOCH ))

        if [ "$ENTRY_EPOCH" -gt 0 ] && [ "$DIFF" -ge 0 ] && [ "$DIFF" -le "$THRESHOLD_SECONDS" ]; then
            FOUND_FRESH=1
            FRESH_LINE="$line"
            break
        fi
    done < "$EVIDENCE_LOG"
fi

# ─── Decision ───
if [ "$FOUND_FRESH" -eq 1 ]; then
    # Fresh evidence found → approve (exit 0, no output)
    exit 0
fi

# No fresh evidence → block with actionable reason
if [ -f "$EVIDENCE_LOG" ] && [ -s "$EVIDENCE_LOG" ]; then
    LAST_LINE=$(grep -v '^[[:space:]]*$' "$EVIDENCE_LOG" | grep -v '^#' | tail -1 || echo "(none)")
    BLOCK_REASON="Figma取得証跡が${THRESHOLD_HOURS}h以上古いか対象外。最終証跡: [${LAST_LINE}]。mcp__figma__view_nodeで最新Figmaデータを取得後、bash scripts/figma_fetch_record.sh <node_id> <description> で証跡を記録してからPR作成せよ。正典マップ: context/figma-canonical-map.md"
else
    BLOCK_REASON="Figma取得証跡なし(logs/figma_fetch_evidence.log未作成/空)。mcp__figma__view_nodeでFigmaデータを取得後、bash scripts/figma_fetch_record.sh <node_id> <description> で証跡を記録してからPR作成せよ。正典マップ: context/figma-canonical-map.md"
fi

python3 -c "
import json, sys
print(json.dumps({'decision': 'block', 'reason': '[figma-fresh-fetch-guard] ' + sys.argv[1]}, ensure_ascii=False))
" "$BLOCK_REASON"
