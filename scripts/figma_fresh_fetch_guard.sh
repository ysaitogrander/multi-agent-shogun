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
BYPASS_FILE="$SCRIPT_DIR/.figma-guard-bypass"
THRESHOLD_HOURS=48

# Load shared guard lib (provides has_fresh_evidence, scans both log + per-PR dir)
# shellcheck source=../lib/figma_guard_common.sh
source "$SCRIPT_DIR/lib/figma_guard_common.sh"

# ─── Read hook input ───
INPUT=$(cat)

# ─── Extract tool_name and command ───
TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" \
    2>/dev/null || echo "")
COMMAND=$(printf '%s' "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" \
    2>/dev/null || echo "")

# ─── Only intercept Bash tool ───
if [ "$TOOL_NAME" != "Bash" ]; then
    exit 0
fi

# ─── Only intercept gh pr create / gh pr new ───
if ! printf '%s' "$COMMAND" | grep -qE 'gh[[:space:]]+(pr[[:space:]]+(create|new)|pr[[:space:]]+create)'; then
    exit 0
fi

# ─── Bypass file check (shogun-authorized emergency skip) ───
if [ -f "$BYPASS_FILE" ]; then
    BYPASS_REASON=$(cat "$BYPASS_FILE" 2>/dev/null || echo "bypass authorized")
    echo "[figma-fresh-fetch-guard] BYPASS active: $BYPASS_REASON" >&2
    exit 0
fi

# ─── Check Figma fetch evidence within threshold (both log + per-PR dir) ───
if has_fresh_evidence "$THRESHOLD_HOURS"; then
    # Fresh evidence found in log or docs/figma-evidence/ → approve
    exit 0
fi

# ─── No fresh evidence → block with actionable message ───
LAST_LOG_LINE=""
if [ -f "$FIGMA_GUARD_EVIDENCE_LOG" ] && [ -s "$FIGMA_GUARD_EVIDENCE_LOG" ]; then
    LAST_LOG_LINE=$(grep -v '^[[:space:]]*$' "$FIGMA_GUARD_EVIDENCE_LOG" | tail -1 || true)
fi

if [ -n "$LAST_LOG_LINE" ]; then
    EVIDENCE_STATUS="最終log証跡: [${LAST_LOG_LINE}] (${THRESHOLD_HOURS}h超過)"
else
    EVIDENCE_STATUS="証跡なし (logs/figma_fetch_evidence.log 未作成または空、docs/figma-evidence/*.md も未コミット)"
fi

BLOCK_REASON="Figma Evidence Guard: 48h以内の証跡が見つかりません。

${EVIDENCE_STATUS}

必要な対応:
  1. 対象画面のFigma nodeを48h以内に実取得 (mcp__figma__view_node または Figma REST API)
  2. 証跡を記録・コミット:
     bash scripts/figma_fetch_record.sh \"<node-id>\" \"<説明>\" --url \"<figma-url>\" --file \"<対象ファイル>\" --pr-file
     git add docs/figma-evidence/<生成file>.md && git commit -m 'chore(figma-evidence): add fetch evidence'
  3. 証跡blockに node/file/fetched(ISO)/url が含まれることを確認

参照: docs/figma-evidence-guard.md / context/figma-canonical-map.md"

python3 -c "
import json, sys
print(json.dumps({'decision': 'block', 'reason': '[figma-fresh-fetch-guard] ' + sys.argv[1]}, ensure_ascii=False))
" "$BLOCK_REASON"
