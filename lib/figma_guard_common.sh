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

# ─── has_fresh_evidence [since_hours] [node_id] ───────────────
# Returns 0 if a Figma fetch was recorded within <since_hours> hours (default: 48).
# If node_id is given, the matching line must also contain "node:<node_id>".
# Returns 1 if no fresh evidence found or the log does not exist.
#
# Compatible with both old log format:
#   <ISO8601> node:<id> by:<agent> [desc]
# and new extended format:
#   <ISO8601> node:<id> url:<url> scope:<paths> by:<agent> [desc]
has_fresh_evidence() {
    local since_hours="${1:-48}"
    local node_id="${2:-}"

    [ -f "$FIGMA_GUARD_EVIDENCE_LOG" ] || return 1

    # Compute cutoff epoch (macOS-first, Linux fallback)
    local cutoff
    cutoff=$(date -v -"${since_hours}"H +%s 2>/dev/null) || \
    cutoff=$(date -d "${since_hours} hours ago" +%s 2>/dev/null) || return 1

    while IFS= read -r line; do
        [ -z "$line" ] && continue

        # Extract timestamp (first whitespace-delimited field)
        local ts_str
        ts_str=$(printf '%s' "$line" | awk '{print $1}')
        [ -z "$ts_str" ] && continue

        # Normalize timezone: +09:00 → +0900 for macOS date -jf
        local ts_norm
        ts_norm=$(printf '%s' "$ts_str" | sed 's/\([+-][0-9][0-9]\):\([0-9][0-9]\)$/\1\2/')

        # Parse epoch (macOS-first, Linux fallback)
        local ts_epoch
        ts_epoch=$(date -jf "%Y-%m-%dT%H:%M:%S%z" "$ts_norm" +%s 2>/dev/null) || \
        ts_epoch=$(date -d "$ts_str" +%s 2>/dev/null) || continue

        [ "$ts_epoch" -ge "$cutoff" ] || continue

        # If node_id given, require "node:<node_id>" in the line
        if [ -n "$node_id" ]; then
            printf '%s' "$line" | grep -q "node:${node_id}" || continue
        fi

        return 0
    done < "$FIGMA_GUARD_EVIDENCE_LOG"

    return 1
}
