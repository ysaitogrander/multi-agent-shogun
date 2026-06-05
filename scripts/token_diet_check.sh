#!/usr/bin/env bash
# token_diet_check.sh — shogun_to_karo.yaml のトークン肥大を早期検知
# 行数 / cmd 数 / active (pending+in_progress) 数を計測し閾値超で警告を出す

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_FILE="$REPO_ROOT/queue/shogun_to_karo.yaml"

# Thresholds
WARN_LINES=600
WARN_ACTIVE=20

[[ -f "$SRC_FILE" ]] || { echo "ERROR: not found: $SRC_FILE" >&2; exit 1; }

# Helper: count lines matching a pattern; 0 if no match (grep -c exits 1 on 0 matches)
count_lines() { grep -c "$1" "$2" 2>/dev/null || true; }

# Status lines always have 2-space indent in this file: "  status: value"
# Using explicit literal patterns avoids \s / \| portability issues on macOS grep
total_lines=$(wc -l < "$SRC_FILE")
total_cmds=$(count_lines '^- id: cmd_' "$SRC_FILE")
pending_cmds=$(count_lines '^  status: pending' "$SRC_FILE")
in_progress_cmds=$(count_lines '^  status: in_progress' "$SRC_FILE")
done_cmds=$(count_lines '^  status: done' "$SRC_FILE")
cancelled_cmds=$(count_lines '^  status: cancelled' "$SRC_FILE")
active_cmds=$((pending_cmds + in_progress_cmds))

# count_lines may output empty string when grep returns 0 (|| true path with no output)
# Normalise to integer 0
normalise() { echo "${1:-0}"; }
total_cmds=$(normalise "$total_cmds")
pending_cmds=$(normalise "$pending_cmds")
in_progress_cmds=$(normalise "$in_progress_cmds")
done_cmds=$(normalise "$done_cmds")
cancelled_cmds=$(normalise "$cancelled_cmds")

archive_file="$REPO_ROOT/queue/archive/shogun_to_karo_archive.yaml"
if [[ -f "$archive_file" ]]; then
    archived_cmds=$(count_lines '^- id: cmd_' "$archive_file")
    archived_cmds=$(normalise "$archived_cmds")
else
    archived_cmds=0
fi

echo "═══ shogun_to_karo.yaml token-diet check ═══"
printf "  Lines    : %d (warn >= %d)\n" "$total_lines" "$WARN_LINES"
printf "  Cmds     : %d total\n" "$total_cmds"
printf "  Active   : %d (%d pending + %d in_progress, warn >= %d)\n" \
    "$active_cmds" "$pending_cmds" "$in_progress_cmds" "$WARN_ACTIVE"
printf "  Done     : %d  |  Cancelled: %d\n" "$done_cmds" "$cancelled_cmds"
printf "  Archived : %d (queue/archive/)\n" "$archived_cmds"
echo "────────────────────────────────────────────"

warn=0

if [[ "$active_cmds" -ge "$WARN_ACTIVE" ]]; then
    printf "WARNING: active cmds (%d) >= threshold (%d)\n" "$active_cmds" "$WARN_ACTIVE"
    echo "  => Run: bash scripts/archive_done_cmds.sh"
    warn=1
fi

if [[ "$total_lines" -ge "$WARN_LINES" ]]; then
    printf "WARNING: line count (%d) >= threshold (%d)\n" "$total_lines" "$WARN_LINES"
    echo "  => Run: bash scripts/archive_done_cmds.sh"
    warn=1
fi

archivable=$((done_cmds + cancelled_cmds))
if [[ "$archivable" -gt 0 ]]; then
    printf "INFO: %d done/cancelled cmds are archivable now\n" "$archivable"
    echo "  => Run: bash scripts/archive_done_cmds.sh"
fi

if [[ "$warn" -eq 0 ]]; then
    printf "OK: within thresholds (lines=%d/%d, active=%d/%d)\n" \
        "$total_lines" "$WARN_LINES" "$active_cmds" "$WARN_ACTIVE"
fi

echo "════════════════════════════════════════════"
exit "$warn"
