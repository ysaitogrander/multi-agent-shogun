#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# figma_fetch_record.sh — Record Figma fetch evidence
# ═══════════════════════════════════════════════════════════════
# Call this immediately after fetching Figma node data via
# mcp__figma__view_node to record evidence for figma-fresh-fetch-guard.
#
# Usage:
#   bash scripts/figma_fetch_record.sh <node_id> [description] \
#     [--url <figma_url>] [--scope <file_paths>] \
#     [--file <target_file>] [--pr-file]
#
# Examples (backward-compatible):
#   bash scripts/figma_fetch_record.sh "4560-89033" "タブレット正典xDQ4U取得"
#   bash scripts/figma_fetch_record.sh "1234-5678"
#
# Examples (extended with url + scope):
#   bash scripts/figma_fetch_record.sh "4560-89033" "正典取得" \
#     --url "https://www.figma.com/design/xDQ4U.../..." \
#     --scope "resources/views/tablet/index.blade.php"
#
# Examples (per-PR file mode — recommended for CI visibility):
#   bash scripts/figma_fetch_record.sh "4560-89033" "正典取得" \
#     --url "https://www.figma.com/design/xDQ4U.../..." \
#     --file "resources/views/admin/index.blade.php" \
#     --pr-file
#
# Examples (per-PR JSON file mode — cmd_715 figma_node_verification compat):
#   bash scripts/figma_fetch_record.sh "4560-89033" "正典取得" \
#     --url "https://www.figma.com/design/xDQ4U.../..." \
#     --file "resources/views/admin/index.blade.php" \
#     --pr-file-json
#
# --pr-file      writes docs/figma-evidence/<branch>_<node>.md  (Markdown block)
# --pr-file-json writes docs/figma-evidence/<branch>_<node>.json (JSON array)
# Both modes also append to the evidence log (backward-compatible).
#
# Output format (log — extended):
#   <ISO8601> node:<id> url:<url> scope:<paths> by:<agent> [desc]
# Output format (log — backward-compatible, when --url/--scope omitted):
#   <ISO8601> node:<id> by:<agent> [desc]
# Output format (per-PR .md):
#   <!-- figma-evidence-block --> section with node/file/fetched/url fields.
# Output format (per-PR .json):
#   [{"node":"<id>","file":"<path>","fetched":"<ISO>","url":"<url>"}]
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_LOG="$SCRIPT_DIR/logs/figma_fetch_evidence.log"
EVIDENCE_DIR="${FIGMA_GUARD_EVIDENCE_DIR:-${SCRIPT_DIR}/docs/figma-evidence}"

# ─── Args (backward-compatible positional + optional named flags) ───
NODE_ID="${1:-}"
if [ -z "$NODE_ID" ]; then
    echo "Usage: bash scripts/figma_fetch_record.sh <node_id> [description] [--url <url>] [--scope <paths>] [--file <target_file>] [--pr-file]" >&2
    exit 1
fi
shift

DESCRIPTION=""
URL=""
SCOPE=""
TARGET_FILE=""
PR_FILE=0
PR_FILE_JSON=0

# Second positional arg (if not a flag) is description — backward compat
if [ $# -gt 0 ] && [ "${1:-}" != "${1#-}" ] 2>/dev/null; then
    : # starts with -, skip
elif [ $# -gt 0 ]; then
    case "${1:-}" in
        --*) : ;;
        *) DESCRIPTION="$1"; shift ;;
    esac
fi

# Parse remaining named flags
while [ $# -gt 0 ]; do
    case "${1:-}" in
        --url)          URL="${2:-}";         shift 2 ;;
        --scope)        SCOPE="${2:-}";       shift 2 ;;
        --desc)         DESCRIPTION="${2:-}"; shift 2 ;;
        --file)         TARGET_FILE="${2:-}"; shift 2 ;;
        --pr-file)      PR_FILE=1;            shift ;;
        --pr-file-json) PR_FILE_JSON=1;       shift ;;
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

# ─── Timestamp ───
TIMESTAMP=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

# ─── Ensure logs dir exists ───
mkdir -p "$SCRIPT_DIR/logs"

# ─── Build log record line ───
RECORD="${TIMESTAMP} node:${NODE_ID}"
[ -n "$URL" ]   && RECORD="${RECORD} url:${URL}"
[ -n "$SCOPE" ] && RECORD="${RECORD} scope:${SCOPE}"
RECORD="${RECORD} by:${AGENT_ID}"
[ -n "$DESCRIPTION" ] && RECORD="${RECORD} ${DESCRIPTION}"

# ─── Append to evidence log (always — both modes) ───
echo "$RECORD" >> "$EVIDENCE_LOG"
echo "[figma-fetch-record] Recorded: $RECORD"
echo "[figma-fetch-record] Evidence log: $EVIDENCE_LOG"

# ─── Per-PR file mode ───
if [ "$PR_FILE" -eq 1 ]; then
    mkdir -p "$EVIDENCE_DIR"

    # Derive safe branch name for filename
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    SAFE_BRANCH=$(printf '%s' "$BRANCH" | tr '/' '_' | tr -cd 'a-zA-Z0-9_-')
    # Normalize node ID for filename: replace : with -
    SAFE_NODE=$(printf '%s' "$NODE_ID" | tr ':' '-' | tr -cd 'a-zA-Z0-9_-')

    PR_FILE_PATH="${EVIDENCE_DIR}/${SAFE_BRANCH}_${SAFE_NODE}.md"

    # Determine file value (TARGET_FILE or SCOPE as fallback)
    FILE_VAL="${TARGET_FILE:-${SCOPE:-}}"

    # Append machine-parseable block to per-PR evidence file
    {
        echo ""
        echo "<!-- figma-evidence-block (machine-parseable・guard走査対象) -->"
        echo "node: ${NODE_ID}"
        echo "file: ${FILE_VAL}"
        echo "fetched: ${TIMESTAMP}"
        echo "url: ${URL}"
        echo "<!-- /figma-evidence-block -->"
    } >> "$PR_FILE_PATH"

    echo "[figma-fetch-record] Per-PR evidence file (md): $PR_FILE_PATH"
    echo "[figma-fetch-record] Commit with: git add ${PR_FILE_PATH} && git commit -m 'chore(figma-evidence): add fetch evidence'"
fi

# ─── Per-PR JSON file mode ───
if [ "$PR_FILE_JSON" -eq 1 ]; then
    mkdir -p "$EVIDENCE_DIR"

    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    SAFE_BRANCH=$(printf '%s' "$BRANCH" | tr '/' '_' | tr -cd 'a-zA-Z0-9_-')
    SAFE_NODE=$(printf '%s' "$NODE_ID" | tr ':' '-' | tr -cd 'a-zA-Z0-9_-')

    JSON_FILE_PATH="${EVIDENCE_DIR}/${SAFE_BRANCH}_${SAFE_NODE}.json"
    FILE_VAL="${TARGET_FILE:-${SCOPE:-}}"

    # Build JSON entry and write/append as array
    # If file already exists, merge; otherwise create new
    if command -v python3 >/dev/null 2>&1; then
        # shellcheck disable=SC2016
        python3 -c '
import sys, json
fpath, node, file_val, fetched, url = sys.argv[1:]
new_entry = {"node": node, "file": file_val, "fetched": fetched, "url": url}
try:
    with open(fpath) as f:
        data = json.load(f)
    if isinstance(data, dict):
        data = [data]
except Exception:
    data = []
data.append(new_entry)
with open(fpath, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
' "$JSON_FILE_PATH" "$NODE_ID" "$FILE_VAL" "$TIMESTAMP" "$URL"
    else
        # Fallback: simple JSON without python3
        printf '[{"node":"%s","file":"%s","fetched":"%s","url":"%s"}]\n' \
            "$NODE_ID" "$FILE_VAL" "$TIMESTAMP" "$URL" > "$JSON_FILE_PATH"
    fi

    echo "[figma-fetch-record] Per-PR evidence file (json): $JSON_FILE_PATH"
    echo "[figma-fetch-record] Commit with: git add ${JSON_FILE_PATH} && git commit -m 'chore(figma-evidence): add fetch evidence'"
fi
