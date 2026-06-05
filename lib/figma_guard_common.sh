#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# lib/figma_guard_common.sh — Shared Figma guard functions
# ═══════════════════════════════════════════════════════════════
# Contract for H2 (pre-push), H3 (CI Action), H4 (assigner):
#
#   source "$(dirname "$0")/../lib/figma_guard_common.sh"
#   is_figma_relevant_path "$path"      → 0=needs-evidence / 1=backend-only
#   has_fresh_evidence [hours] [node]   → 0=fresh / 1=stale-or-missing
#
# Override evidence log path before sourcing if needed:
#   export FIGMA_GUARD_EVIDENCE_LOG="/custom/path/evidence.log"
#
# Limitation (honest): push payloads carry no node metadata.
# "48h-window + optional node_id match" is the practical approximation.
# Complete node×file correlation is a future work item.
# ═══════════════════════════════════════════════════════════════

# Resolve project root relative to this file (lib/ is one level below root)
_FIGMA_GUARD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Evidence log — override via env before sourcing
FIGMA_GUARD_EVIDENCE_LOG="${FIGMA_GUARD_EVIDENCE_LOG:-${_FIGMA_GUARD_ROOT}/logs/figma_fetch_evidence.log}"

# Per-PR evidence directory — override via env before sourcing
FIGMA_GUARD_EVIDENCE_DIR="${FIGMA_GUARD_EVIDENCE_DIR:-${_FIGMA_GUARD_ROOT}/docs/figma-evidence}"

# ─── is_figma_relevant_path <path> ────────────────────────────
# Returns 0 (true)  — path may touch Figma-governed UI → evidence required.
# Returns 1 (false) — path is definitively backend-only → no evidence needed.
#
# Conservative (false-negative-safe): unknown paths default to 0.
#
# Allowlist (evidence required — checked first):
#   resources/views/**/*.blade.php, *.css, *.scss, *.sass,
#   tailwind.config.*, resources/js/**, resources/ts/**,
#   resources/vue/**, public/**/*.{css,js}
#
# Denylist (backend-only, no evidence needed):
#   app/**, database/migrations/**, tests/**, routes/**, config/**
is_figma_relevant_path() {
    local path="$1"

    # Allowlist — evidence required (checked before denylist)
    if printf '%s' "$path" | grep -qE \
        '(resources/views/.*\.blade\.php|\.blade\.php$|\.css$|\.scss$|\.sass$|tailwind\.config\.|resources/js/|resources/ts/|resources/vue/|public/.*\.(css|js)$)'; then
        return 0
    fi

    # Denylist — definitively backend-only (any prefix like src/ is tolerated)
    if printf '%s' "$path" | grep -qE \
        '(^|.*/)(app|database/migrations|tests|routes|config)/'; then
        return 1
    fi

    # Unknown path — default to evidence required (false-negative-safe)
    return 0
}

# ─── is_definitely_figma_ui <path> ────────────────────────────
# Returns 0 (true)  — path is definitively Figma-governed UI (allowlist match).
# Returns 1 (false) — path is unknown or backend-only → no evidence required.
#
# Positive-only (contrast with is_figma_relevant_path):
#   Unknown paths → 1 (false). Use for Layer2 assigner gate where
#   blocking non-Figma routes is an error. CI (H2/H3) uses
#   is_figma_relevant_path (conservative) as the authoritative backstop.
#
# Allowlist (positive Figma UI — same set as is_figma_relevant_path):
#   resources/views/**/*.blade.php, *.css, *.scss, *.sass,
#   tailwind.config.*, resources/js/**, resources/ts/**,
#   resources/vue/**, public/**/*.{css,js}
is_definitely_figma_ui() {
    local path="$1"

    # Positive allowlist — definitively Figma-governed UI
    if printf '%s' "$path" | grep -qE \
        '(resources/views/.*\.blade\.php|\.blade\.php$|\.css$|\.scss$|\.sass$|tailwind\.config\.|resources/js/|resources/ts/|resources/vue/|public/.*\.(css|js)$)'; then
        return 0
    fi

    # Unknown or backend-only path — no evidence required (positive-only)
    return 1
}

# ─── _figma_guard_compute_cutoff <since_hours> ────────────────
# Prints cutoff epoch to stdout. Returns 1 on failure.
_figma_guard_compute_cutoff() {
    local since_hours="$1"
    date -v -"${since_hours}"H +%s 2>/dev/null || \
    date -d "${since_hours} hours ago" +%s 2>/dev/null
}

# ─── _figma_guard_parse_epoch <ts_str> ────────────────────────
# Prints epoch to stdout. Returns 1 on failure.
_figma_guard_parse_epoch() {
    local ts_str="$1"
    local ts_norm
    ts_norm=$(printf '%s' "$ts_str" | sed 's/\([+-][0-9][0-9]\):\([0-9][0-9]\)$/\1\2/')
    date -jf "%Y-%m-%dT%H:%M:%S%z" "$ts_norm" +%s 2>/dev/null || \
    date -d "$ts_str" +%s 2>/dev/null
}

# ─── _scan_md_evidence_file <file> <cutoff_epoch> [node_id] ──
# Parses machine-parseable blocks in a .md evidence file.
# Block format:
#   <!-- figma-evidence-block (machine-parseable・guard走査対象) -->
#   node: <node_id>
#   fetched: <ISO8601>
#   <!-- /figma-evidence-block -->
# Returns 0 if any block with fetched >= cutoff (and node match if given).
_scan_md_evidence_file() {
    local mdfile="$1"
    local cutoff="$2"
    local node_id="${3:-}"

    local in_block=0
    local block_node="" block_fetched=""

    while IFS= read -r line; do
        case "$line" in
            *'<!-- figma-evidence-block'*)
                in_block=1; block_node=""; block_fetched=""
                ;;
            *'<!-- /figma-evidence-block'*)
                if [ "$in_block" -eq 1 ] && [ -n "$block_fetched" ]; then
                    local ts_epoch
                    ts_epoch=$(_figma_guard_parse_epoch "$block_fetched") || { in_block=0; continue; }
                    if [ "$ts_epoch" -ge "$cutoff" ]; then
                        if [ -z "$node_id" ] || printf '%s' "$block_node" | grep -qF "$node_id"; then
                            return 0
                        fi
                    fi
                fi
                in_block=0
                ;;
            *)
                if [ "$in_block" -eq 1 ]; then
                    case "$line" in
                        'node: '*)    block_node="${line#node: }";;
                        'node:'*)     block_node="${line#node:}";;
                        'fetched: '*) block_fetched="${line#fetched: }";;
                        'fetched:'*)  block_fetched="${line#fetched:}";;
                    esac
                fi
                ;;
        esac
    done < "$mdfile"

    return 1
}

# ─── _scan_json_evidence_file <file> <cutoff_epoch> [node_id] ─
# Parses a JSON evidence file (single object or array of objects).
# JSON format: {"node":"<id>","fetched":"<ISO8601>",...}
# Accepts both "node" and "node_id" keys; "fetched" and "fetched_at".
# Requires python3 (already a project dependency).
# Returns 0 if any entry with fetched >= cutoff (and node match if given).
_scan_json_evidence_file() {
    local jsonfile="$1"
    local cutoff="$2"
    local node_id="${3:-}"

    command -v python3 >/dev/null 2>&1 || return 1

    local result
    # shellcheck disable=SC2016
    result=$(python3 -c '
import sys, json
from datetime import datetime, timezone
try:
    fpath, cutoff_s, nf = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    with open(fpath) as f:
        data = json.load(f)
    if isinstance(data, dict):
        data = [data]
    for e in data:
        fetched = e.get("fetched") or e.get("fetched_at") or ""
        node = e.get("node") or e.get("node_id") or ""
        if not fetched:
            continue
        try:
            dt = datetime.fromisoformat(fetched.replace("Z", "+00:00"))
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            ts = int(dt.timestamp())
        except Exception:
            continue
        if ts < cutoff_s:
            continue
        if nf and nf not in node:
            continue
        print("FOUND")
        sys.exit(0)
except Exception:
    pass
' "$jsonfile" "$cutoff" "${node_id:-}" 2>/dev/null || true)

    [ "$result" = "FOUND" ]
}

# ─── _scan_evidence_dir <dir> <cutoff_epoch> [node_id] ────────
# Scans docs/figma-evidence/ for machine-parseable evidence files.
# Accepts both *.md (HTML comment block format) and *.json (object/array format).
# Returns 0 if any entry with fetched >= cutoff (and node match if given).
_scan_evidence_dir() {
    local dir="$1"
    local cutoff="$2"
    local node_id="${3:-}"

    [ -d "$dir" ] || return 1

    local evfile
    for evfile in "$dir"/*.md "$dir"/*.json; do
        [ -f "$evfile" ] || continue
        case "$evfile" in
            *.json) _scan_json_evidence_file "$evfile" "$cutoff" "$node_id" && return 0 ;;
            *.md)   _scan_md_evidence_file   "$evfile" "$cutoff" "$node_id" && return 0 ;;
        esac
    done

    return 1
}

# ─── has_fresh_evidence [since_hours] [node_id] ───────────────
# Returns 0 if a Figma fetch was recorded within <since_hours> hours (default: 48).
# If node_id is given, the matching record must also contain that node ID.
# Returns 1 if no fresh evidence found in either source.
#
# Source 1 (backward-compatible): logs/figma_fetch_evidence.log
#   <ISO8601> node:<id> by:<agent> [desc]   (old format)
#   <ISO8601> node:<id> url:<url> scope:<paths> by:<agent> [desc]  (new format)
#
# Source 2 (per-PR, CI-available): docs/figma-evidence/*.md
#   Machine-parseable <!-- figma-evidence-block --> sections.
#   Committed per-PR so CI can read them without needing the gitignored log.
#
# OR semantics: fresh evidence in either source → returns 0.
has_fresh_evidence() {
    local since_hours="${1:-48}"
    local node_id="${2:-}"

    local cutoff
    cutoff=$(_figma_guard_compute_cutoff "$since_hours") || return 1

    # Source 1: log file (pre-push / local)
    if [ -f "$FIGMA_GUARD_EVIDENCE_LOG" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue

            local ts_str
            ts_str=$(printf '%s' "$line" | awk '{print $1}')
            [ -z "$ts_str" ] && continue

            local ts_epoch
            ts_epoch=$(_figma_guard_parse_epoch "$ts_str") || continue

            [ "$ts_epoch" -ge "$cutoff" ] || continue

            if [ -n "$node_id" ]; then
                printf '%s' "$line" | grep -q "node:${node_id}" || continue
            fi

            return 0
        done < "$FIGMA_GUARD_EVIDENCE_LOG"
    fi

    # Source 2: per-PR evidence directory (CI-available committed files)
    _scan_evidence_dir "$FIGMA_GUARD_EVIDENCE_DIR" "$cutoff" "$node_id" && return 0

    return 1
}
