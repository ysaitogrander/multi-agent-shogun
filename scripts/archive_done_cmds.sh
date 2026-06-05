#!/usr/bin/env bash
# archive_done_cmds.sh — shogun_to_karo.yaml の done/cancelled cmd を archive へ退避
# 軽量化によりトークン消費を削減。既 archive 済 cmd の二重退避を防ぐ guard 付き。
# 既存 scripts/archive_done_commands.sh を統合・修正した上位互換版。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUE_DIR="$REPO_ROOT/queue"
SRC_FILE="$QUEUE_DIR/shogun_to_karo.yaml"
ARCHIVE_FILE="$QUEUE_DIR/archive/shogun_to_karo_archive.yaml"
BACKUP_FILE="$SRC_FILE.bak_archive"
LOG_DIR="$REPO_ROOT/logs"
LOG_FILE="$LOG_DIR/archive_done_cmds.log"

PY="python3"

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] $*" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR: $1"
    if [[ -f "$BACKUP_FILE" ]]; then
        log "Restoring backup…"
        cp "$BACKUP_FILE" "$SRC_FILE"
        log "Rollback complete."
    fi
    exit 1
}

main() {
    log "=== archive_done_cmds START ==="

    [[ -f "$SRC_FILE" ]]   || error_exit "source file not found: $SRC_FILE"
    command -v "$PY" >/dev/null 2>&1 || error_exit "python3 not found"

    # Ensure log and archive dirs exist
    mkdir -p "$LOG_DIR" "$(dirname "$ARCHIVE_FILE")"

    # Pre-count (pattern matches current file format: "- id: cmd_NNN" at col 0)
    local total_before
    total_before=$(grep -c '^- id: cmd_' "$SRC_FILE" 2>/dev/null) || total_before=0
    log "Total cmds before: $total_before"

    if [[ "$total_before" -lt 3 ]]; then
        log "Fewer than 3 cmds — nothing to archive."
        log "=== archive_done_cmds SKIPPED ==="
        return 0
    fi

    log "Creating backup: $BACKUP_FILE"
    cp "$SRC_FILE" "$BACKUP_FILE" || error_exit "backup failed"

    log "Running archive (Python)…"
    ARCH_SRC="$SRC_FILE" ARCH_DEST="$ARCHIVE_FILE" \
    "$PY" - <<'PYEOF' || error_exit "Python archive step failed"
import sys, re, yaml, os
from pathlib import Path
from datetime import datetime, timezone

src_path  = Path(os.environ['ARCH_SRC'])
arch_path = Path(os.environ['ARCH_DEST'])

# ── Load source ─────────────────────────────────────────────────────────────
raw = src_path.read_text(encoding='utf-8')
parsed = yaml.safe_load(raw)
if not isinstance(parsed, dict) or not isinstance(parsed.get('commands'), list):
    print("ERROR: unexpected structure in source YAML", file=sys.stderr)
    sys.exit(1)

all_cmds = parsed['commands']

# ── Load already-archived IDs (double-archive guard) ────────────────────────
archived_ids: set = set()
if arch_path.exists():
    arch_raw = arch_path.read_text(encoding='utf-8')
    # Archive file may start with a comment line (not a YAML doc separator)
    # Strip leading comment lines for safe_load
    arch_lines = arch_raw.splitlines()
    yaml_lines = [l for l in arch_lines if not l.startswith('#')]
    try:
        arch_parsed = yaml.safe_load('\n'.join(yaml_lines))
    except yaml.YAMLError:
        arch_parsed = None
    if isinstance(arch_parsed, list):
        archived_ids = {item['id'] for item in arch_parsed if isinstance(item, dict) and 'id' in item}
    print(f"Already archived IDs: {sorted(archived_ids)}", file=sys.stderr)

# ── Separate keep / to-archive ───────────────────────────────────────────────
keep_cmds = []
arch_cmds = []

for cmd in all_cmds:
    st = cmd.get('status', '')
    if st in ('done', 'cancelled'):
        cmd_id = cmd.get('id', '')
        if cmd_id in archived_ids:
            print(f"SKIP (already archived): {cmd_id}", file=sys.stderr)
            keep_cmds.append(cmd)  # keep it out of main, guard fires
        else:
            arch_cmds.append(cmd)
    else:
        keep_cmds.append(cmd)

print(f"total={len(all_cmds)} keep={len(keep_cmds)} to-archive={len(arch_cmds)}", file=sys.stderr)

if not arch_cmds:
    print("No new done/cancelled cmds to archive.", file=sys.stderr)
    sys.exit(0)

# ── Write updated source ─────────────────────────────────────────────────────
updated_src = {'commands': keep_cmds}
src_path.write_text(
    yaml.dump(updated_src, allow_unicode=True, default_flow_style=False, sort_keys=False),
    encoding='utf-8',
)

# ── Append to archive ────────────────────────────────────────────────────────
now_str = datetime.now(timezone.utc).astimezone().strftime('%Y-%m-%d')
header = f"# archived {now_str} — {', '.join(c.get('id','?') for c in arch_cmds)} (status=done/cancelled)\n"

new_block = yaml.dump(
    arch_cmds, allow_unicode=True, default_flow_style=False, sort_keys=False
)

if arch_path.exists():
    existing = arch_path.read_text(encoding='utf-8')
    if not existing.endswith('\n'):
        existing += '\n'
    arch_path.write_text(existing + header + new_block, encoding='utf-8')
else:
    arch_path.write_text(header + new_block, encoding='utf-8')

print(f"SUCCESS: archived {len(arch_cmds)} cmds; {len(keep_cmds)} remain active", file=sys.stderr)
PYEOF

    # Post-count
    local active_after archive_total
    active_after=$(grep -c '^- id: cmd_' "$SRC_FILE" 2>/dev/null) || active_after=0
    archive_total=$(grep -c '^- id: cmd_' "$ARCHIVE_FILE" 2>/dev/null) || archive_total=0

    # YAML validation
    log "Validating YAML syntax…"
    "$PY" -c "
import yaml, sys
for p in ['$SRC_FILE', '$ARCHIVE_FILE']:
    try:
        yaml.safe_load(open(p).read())
    except yaml.YAMLError as e:
        print(f'YAML error in {p}: {e}', file=sys.stderr)
        sys.exit(1)
print('YAML validation passed')
" || error_exit "YAML validation failed"

    rm -f "$BACKUP_FILE"

    log "Active after: $active_after  |  Archive total: $archive_total"
    log "=== archive_done_cmds COMPLETE ==="
}

main "$@"
