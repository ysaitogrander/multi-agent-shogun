#!/usr/bin/env bats
# test_figma_guard_evidence.bats — has_fresh_evidence unit tests
# cmd_717(B): figma-evidence-guard per-PR証跡走査化
# 8ケース: ガード弱体化ゼロ検証（赤→緑の退行なし）

setup_file() {
    export PROJECT_ROOT
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export GUARD_LIB="$PROJECT_ROOT/lib/figma_guard_common.sh"
    [ -f "$GUARD_LIB" ] || { echo "SKIP: lib/figma_guard_common.sh not found" >&2; return 1; }
}

setup() {
    # Create isolated temp dirs for each test
    export TEST_TMP
    TEST_TMP="$(mktemp -d)"
    export FIGMA_GUARD_EVIDENCE_LOG="$TEST_TMP/evidence.log"
    export FIGMA_GUARD_EVIDENCE_DIR="$TEST_TMP/figma-evidence"
    mkdir -p "$FIGMA_GUARD_EVIDENCE_DIR"

    # Source guard lib with test env vars applied
    # shellcheck disable=SC1090
    source "$GUARD_LIB"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ─── Helper: generate ISO8601 timestamp ───────────────────────

fresh_ts() {
    # Current time (within 48h window)
    date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z
}

stale_ts() {
    # 49 hours ago (outside 48h window)
    date -v -49H -Iseconds 2>/dev/null || date -d "49 hours ago" -Iseconds 2>/dev/null || echo "2020-01-01T00:00:00+09:00"
}

write_pr_file() {
    # write_pr_file <filename> <node> <fetched_ts> [url]
    local fname="$1" node="$2" ts="$3" url="${4:-https://www.figma.com/design/test/?node-id=${2}}"
    {
        echo "# Figma取得証跡テスト"
        echo ""
        echo "<!-- figma-evidence-block (machine-parseable・guard走査対象) -->"
        echo "node: ${node}"
        echo "file: resources/views/test.blade.php"
        echo "fetched: ${ts}"
        echo "url: ${url}"
        echo "<!-- /figma-evidence-block -->"
    } > "$FIGMA_GUARD_EVIDENCE_DIR/$fname"
}

write_json_file() {
    # write_json_file <filename> <node> <fetched_ts>
    local fname="$1" node="$2" ts="$3"
    printf '[{"node":"%s","file":"resources/views/test.blade.php","fetched":"%s","url":"https://figma.com/test"}]\n' \
        "$node" "$ts" > "$FIGMA_GUARD_EVIDENCE_DIR/$fname"
}

# ─── JSON format cases (A-717a-1補足: *.md と *.json 両受理) ──
@test "JSON-Case1: per-PR .json file within 48h with matching node → fresh (green)" {
    write_json_file "branch_4560-47251.json" "4560:47251" "$(fresh_ts)"
    run has_fresh_evidence 48 "4560:47251"
    [ "$status" -eq 0 ]
}

@test "JSON-Case2: per-PR .json file older than 48h → stale (red, guard maintained)" {
    write_json_file "branch_4560-47251.json" "4560:47251" "$(stale_ts)"
    run has_fresh_evidence 48 "4560:47251"
    [ "$status" -ne 0 ]
}

@test "JSON-Case3: .json with mismatched node → stale (red)" {
    write_json_file "branch_4560-47251.json" "4560:47251" "$(fresh_ts)"
    run has_fresh_evidence 48 "9999:99999"
    [ "$status" -ne 0 ]
}

@test "JSON-Case4: mixed .md and .json files — both accepted (green if either fresh)" {
    write_pr_file "branch_node_a.md"   "4560:11111" "$(fresh_ts)"
    write_json_file "branch_node_b.json" "4560:22222" "$(fresh_ts)"
    # Each node found
    run has_fresh_evidence 48 "4560:11111"
    [ "$status" -eq 0 ]
    run has_fresh_evidence 48 "4560:22222"
    [ "$status" -eq 0 ]
}

# ─── Case 1: per-PR file（コミット済・48h内・node一致）→ 緑 ──
@test "Case1: per-PR file within 48h with matching node → fresh (green)" {
    write_pr_file "branch_4560-47251.md" "4560:47251" "$(fresh_ts)"
    run has_fresh_evidence 48 "4560:47251"
    [ "$status" -eq 0 ]
}

# ─── Case 2: log（local pre-push・48h内）→ 緑（後方互換）────
@test "Case2: log file within 48h → fresh (green, backward-compatible)" {
    echo "$(fresh_ts) node:9999:1111 by:ashigaru2 テスト証跡" > "$FIGMA_GUARD_EVIDENCE_LOG"
    run has_fresh_evidence 48
    [ "$status" -eq 0 ]
}

# ─── Case 3: 証跡なし → 赤（維持）───────────────────────────
@test "Case3: no evidence at all → stale (red, guard maintained)" {
    # No log, no per-PR files
    run has_fresh_evidence 48
    [ "$status" -ne 0 ]
}

# ─── Case 4: 証跡あるが48h超過 → 赤（維持）─────────────────
@test "Case4: per-PR file exists but older than 48h → stale (red)" {
    write_pr_file "branch_4560-47251.md" "4560:47251" "$(stale_ts)"
    run has_fresh_evidence 48 "4560:47251"
    [ "$status" -ne 0 ]
}

@test "Case4b: log entry older than 48h → stale (red)" {
    echo "$(stale_ts) node:4560:47251 by:ashigaru2 古い証跡" > "$FIGMA_GUARD_EVIDENCE_LOG"
    run has_fresh_evidence 48 "4560:47251"
    [ "$status" -ne 0 ]
}

# ─── Case 5: node不一致（別画面node指定時）→ 赤（node指定時）
@test "Case5: per-PR file has different node than requested → stale (red)" {
    # File has node 4560:47251 but we check for 9999:99999
    write_pr_file "branch_4560-47251.md" "4560:47251" "$(fresh_ts)"
    run has_fresh_evidence 48 "9999:99999"
    [ "$status" -ne 0 ]
}

@test "Case5b: no node filter → any fresh node passes (green)" {
    write_pr_file "branch_4560-47251.md" "4560:47251" "$(fresh_ts)"
    run has_fresh_evidence 48
    [ "$status" -eq 0 ]
}

# ─── Case 6: infra/backend/test/doc変更 → 誤発火せず（exempt維持）
@test "Case6: is_figma_relevant_path returns 1 for backend-only paths (no evidence required)" {
    run is_figma_relevant_path "app/Http/Controllers/FooController.php"
    [ "$status" -ne 0 ]
}

@test "Case6b: is_figma_relevant_path returns 1 for database migration" {
    run is_figma_relevant_path "database/migrations/2026_01_01_create_foo.php"
    [ "$status" -ne 0 ]
}

@test "Case6c: is_definitely_figma_ui returns 1 for tests/ path (no UI evidence needed)" {
    run is_definitely_figma_ui "tests/Unit/FooTest.php"
    [ "$status" -ne 0 ]
}

@test "Case6d: is_definitely_figma_ui returns 1 for config/ path (exempt)" {
    run is_definitely_figma_ui "config/app.php"
    [ "$status" -ne 0 ]
}

@test "Case6e: is_definitely_figma_ui returns 0 for blade template (UI evidence required)" {
    run is_definitely_figma_ui "resources/views/admin/index.blade.php"
    [ "$status" -eq 0 ]
}

# ─── Case 7: 並行2ブランチ各々UI+証跡 → 各々独立に緑（衝突なし）
@test "Case7: parallel branches have separate per-PR files, each passes independently" {
    # Branch A: feature/branch-a with node A
    write_pr_file "feature_branch-a_4560-11111.md" "4560:11111" "$(fresh_ts)"
    # Branch B: feature/branch-b with node B
    write_pr_file "feature_branch-b_4560-22222.md" "4560:22222" "$(fresh_ts)"

    # Branch A evidence found
    run has_fresh_evidence 48 "4560:11111"
    [ "$status" -eq 0 ]

    # Branch B evidence found (independently)
    run has_fresh_evidence 48 "4560:22222"
    [ "$status" -eq 0 ]

    # No cross-contamination: asking for unknown node → red
    run has_fresh_evidence 48 "9999:99999"
    [ "$status" -ne 0 ]
}

# ─── Case 8: 旧log運用のみ（per-PR file無し）→ 緑（後方互換）
@test "Case8: log-only (no per-PR dir files) still passes (backward compatible)" {
    echo "$(fresh_ts) node:4560:47251 url:https://www.figma.com/design/test/ by:ashigaru2 後方互換" > "$FIGMA_GUARD_EVIDENCE_LOG"
    # No per-PR files created
    run has_fresh_evidence 48 "4560:47251"
    [ "$status" -eq 0 ]
}

# ─── 退行ゼロ保証: 証跡なしUI変更=赤 (must NOT regress to green) ──
@test "Regression-guard: empty evidence dir + no log → stale (red, must not become green)" {
    # Evidence dir exists but is empty; no log
    run has_fresh_evidence 48
    [ "$status" -ne 0 ]
}

@test "Regression-guard: stale per-PR file only (no log) → stale (red)" {
    write_pr_file "branch_node.md" "4560:47251" "$(stale_ts)"
    run has_fresh_evidence 48 "4560:47251"
    [ "$status" -ne 0 ]
}
