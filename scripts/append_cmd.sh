#!/usr/bin/env bash
# append_cmd.sh — shogun_to_karo.yaml に新 cmd を安全に追記
# 値を自動 quote / ブロックスカラー化し YAML 破損を防ぐ (line-397 再発防止)
# append 後 python3 yaml.safe_load で構文検証

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_FILE="$REPO_ROOT/queue/shogun_to_karo.yaml"

usage() {
    cat >&2 <<'EOF'
Usage: bash scripts/append_cmd.sh --id CMD_ID [OPTIONS]

Options:
  --id CMD_ID            CMD ID (e.g. cmd_720)  [required]
  --north-star TEXT      north_star value
  --purpose TEXT         purpose value
  --command TEXT         command value (multi-line OK)
  --criteria TEXT        acceptance_criteria item (repeat for multiple items)
  --project TEXT         project name
  --priority TEXT        high/medium/low  [default: medium]
  --status TEXT          pending/in_progress/done  [default: pending]
  --timestamp TEXT       ISO8601 timestamp  [default: current time]

Multi-line values: quote with $'...' or pass via process substitution.
Example:
  bash scripts/append_cmd.sh \
    --id cmd_720 \
    --north-star "北極星テキスト" \
    --purpose "目的テキスト" \
    --criteria "完了条件1" --criteria "完了条件2" \
    --command "コマンドテキスト" \
    --project my-project \
    --priority high
EOF
    exit 1
}

CMD_ID=""
NORTH_STAR=""
PURPOSE=""
COMMAND_TEXT=""
PROJECT=""
PRIORITY="medium"
STATUS="pending"
TIMESTAMP=""
CRITERIA_ITEMS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --id)           CMD_ID="$2";         shift 2 ;;
        --north-star)   NORTH_STAR="$2";     shift 2 ;;
        --purpose)      PURPOSE="$2";        shift 2 ;;
        --command)      COMMAND_TEXT="$2";   shift 2 ;;
        --criteria)     CRITERIA_ITEMS+=("$2"); shift 2 ;;
        --project)      PROJECT="$2";        shift 2 ;;
        --priority)     PRIORITY="$2";       shift 2 ;;
        --status)       STATUS="$2";         shift 2 ;;
        --timestamp)    TIMESTAMP="$2";      shift 2 ;;
        -h|--help)      usage ;;
        *) echo "ERROR: Unknown option: $1" >&2; usage ;;
    esac
done

[[ -n "$CMD_ID" ]] || { echo "ERROR: --id is required" >&2; usage; }
[[ -f "$SRC_FILE" ]] || { echo "ERROR: source file not found: $SRC_FILE" >&2; exit 1; }

# Duplicate ID guard (use Python to avoid ugrep treating "- id: ..." as options)
if python3 -c "
import yaml, sys
d = yaml.safe_load(open('$SRC_FILE').read())
sys.exit(0 if '$CMD_ID' in [c.get('id','') for c in d.get('commands',[])] else 1)
" 2>/dev/null; then
    echo "ERROR: ${CMD_ID} already exists in $SRC_FILE" >&2
    exit 1
fi

# Backup
BACKUP="${SRC_FILE}.bak_append"
cp "$SRC_FILE" "$BACKUP"

rollback() {
    if [[ -f "$BACKUP" ]]; then
        cp "$BACKUP" "$SRC_FILE"
        echo "Rolled back to backup." >&2
        rm -f "$BACKUP"
    fi
}
trap 'EC=$?; [[ $EC -ne 0 ]] && rollback; rm -f "$BACKUP"; exit $EC' EXIT

# Encode criteria array as NUL-separated string for safe env var transport
# Each item separated by ASCII unit separator (0x1F) to avoid newline ambiguity
CRITERIA_ENV=""
for item in "${CRITERIA_ITEMS[@]+"${CRITERIA_ITEMS[@]}"}"; do
    CRITERIA_ENV="${CRITERIA_ENV}${item}"$'\x1f'
done

# Pass data via env vars (avoids shell interpolation inside Python heredoc)
APPEND_FILE="$SRC_FILE" \
APPEND_ID="$CMD_ID" \
APPEND_NORTH_STAR="$NORTH_STAR" \
APPEND_PURPOSE="$PURPOSE" \
APPEND_COMMAND="$COMMAND_TEXT" \
APPEND_CRITERIA="$CRITERIA_ENV" \
APPEND_PROJECT="$PROJECT" \
APPEND_PRIORITY="$PRIORITY" \
APPEND_STATUS="$STATUS" \
APPEND_TIMESTAMP="$TIMESTAMP" \
python3 - <<'PYEOF'
import os, sys, yaml
from datetime import datetime, timezone

src_path = os.environ['APPEND_FILE']
cmd_id    = os.environ['APPEND_ID']
timestamp = os.environ.get('APPEND_TIMESTAMP', '').strip()
if not timestamp:
    timestamp = datetime.now(timezone.utc).astimezone().strftime('%Y-%m-%dT%H:%M:%S%z')
    # reformat +0900 → +09:00
    if len(timestamp) > 5 and timestamp[-5] in ('+', '-') and ':' not in timestamp[-5:]:
        timestamp = timestamp[:-2] + ':' + timestamp[-2:]

north_star   = os.environ.get('APPEND_NORTH_STAR', '').strip()
purpose      = os.environ.get('APPEND_PURPOSE', '').strip()
command_text = os.environ.get('APPEND_COMMAND', '').strip()
project      = os.environ.get('APPEND_PROJECT', '').strip()
priority     = os.environ.get('APPEND_PRIORITY', 'medium').strip()
status       = os.environ.get('APPEND_STATUS', 'pending').strip()

criteria_raw = os.environ.get('APPEND_CRITERIA', '')
criteria = [c for c in criteria_raw.split('\x1f') if c.strip()]

# Use literal block scalar for multi-line strings
class _Literal(str): pass

def _literal_rep(dumper, data):
    return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='|')

yaml.add_representer(_Literal, _literal_rep, Dumper=yaml.Dumper)

def maybe_literal(v):
    if isinstance(v, str) and '\n' in v:
        return _Literal(v)
    return v

# Build command dict (omit empty optional fields)
cmd = {'id': cmd_id, 'timestamp': timestamp}
if north_star:   cmd['north_star'] = maybe_literal(north_star)
if purpose:      cmd['purpose']    = maybe_literal(purpose)
if criteria:     cmd['acceptance_criteria'] = [maybe_literal(c) for c in criteria]
if command_text: cmd['command']    = maybe_literal(command_text)
if project:      cmd['project']    = project
cmd['priority'] = priority
cmd['status']   = status

# Render as YAML list block (produces "- id: ...\n  key: val\n ...")
block = yaml.dump(
    [cmd],
    allow_unicode=True,
    default_flow_style=False,
    sort_keys=False,
    Dumper=yaml.Dumper,
)

# Append to file
current = open(src_path, encoding='utf-8').read()
if not current.endswith('\n'):
    current += '\n'
updated = current + block

# Validate full file
try:
    parsed = yaml.safe_load(updated)
except yaml.YAMLError as e:
    print(f"ERROR: YAML validation failed after append: {e}", file=sys.stderr)
    sys.exit(1)

if not isinstance(parsed, dict) or not isinstance(parsed.get('commands'), list):
    print("ERROR: 'commands' key missing or not a list after append", file=sys.stderr)
    sys.exit(1)

total = len(parsed['commands'])

# Write
with open(src_path, 'w', encoding='utf-8') as f:
    f.write(updated)

print(f"SUCCESS: appended {cmd_id} → {total} total cmds in shogun_to_karo.yaml")
PYEOF

echo "Append complete. Backup removed."
