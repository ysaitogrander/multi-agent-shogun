#!/usr/bin/env bash
# assign_to_copilot.sh — KaroがCopilot足軽にタスクを割り当てるヘルパー
# (Karo/Shogunが手動で呼ぶか、Claude側のスクリプトから呼ぶ)
#
# ═══════════════════════════════════════════════════════════════
# PROTOCOL: Copilot work は Karo の明示配賦のみ (Copilot自己選択禁止)
# ═══════════════════════════════════════════════════════════════
# Copilot足軽への作業委譲は、本スクリプトを通じた Karo の明示的な
# 配賦のみで行う。Copilot による自己選択・自己割当は禁止。
# 配賦経路を本スクリプト一本に絞ることでコード的に強制する。
# ═══════════════════════════════════════════════════════════════
#
# Usage:
#   bash assign_to_copilot.sh <task_id> <purpose> <command> <project> [priority]
#
# Example:
#   bash assign_to_copilot.sh "subtask_101" "フロントエンドのバグを修正" \
#     "src/components/Button.tsxのonClickを修正" "line_raffle" high

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHOGUN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TASK_FILE="$SHOGUN_ROOT/queue/tasks/ashigaru_copilot.yaml"
INBOX_WRITE="$SHOGUN_ROOT/scripts/inbox_write.sh"
NTFY_SCRIPT="$SHOGUN_ROOT/scripts/ntfy.sh"

TASK_ID="${1:-}"
PURPOSE="${2:-}"
COMMAND="${3:-}"
PROJECT="${4:-}"
PRIORITY="${5:-medium}"

if [ -z "$TASK_ID" ] || [ -z "$PURPOSE" ] || [ -z "$COMMAND" ]; then
    echo "Usage: assign_to_copilot.sh <task_id> <purpose> <command> <project> [priority]" >&2
    exit 1
fi

# 共有安全ゲート: lib/copilot_safety.sh から validate_command / warn_external_api をロード
source "$SCRIPT_DIR/../lib/copilot_safety.sh"

# Figma委譲ゲート共有ライブラリ (H1 lib/figma_guard_common.sh を source して判定共用)
source "$SCRIPT_DIR/../lib/figma_guard_common.sh"

# ── バリデーション実行 (書込前) ──────────────────────────────────
if ! validate_command "$COMMAND"; then
    exit 1
fi
warn_external_api "$COMMAND"

# ── 在flight足軽との対象重複 dedupガード (RACE-001) ──────────────
# 委譲対象(ファイルパス/PR番号/チケットID)が在flightの足軽タスクと
# 重複する場合は配賦を中止する。保守的判定: 明確な同一ファイル/同一PR/
# 同一チケットIDのみを衝突とする。
check_dedup_conflict() {
    local purpose="$1"
    local command="$2"
    local tasks_dir="$SHOGUN_ROOT/queue/tasks"
    local combined="$purpose $command"

    # 対象識別子の抽出 (保守的: 明確な同一対象のみ衝突とする)
    # ファイルパス: スラッシュを含む文字列 (例: src/components/Button.tsx)
    local file_paths
    file_paths=$(echo "$combined" | grep -oE '[a-zA-Z0-9_][a-zA-Z0-9_./-]*/[a-zA-Z0-9_./-]+' 2>/dev/null || true)

    # PR番号: #NNN または PR-NNN / PR/NNN 形式
    local pr_numbers
    pr_numbers=$(echo "$combined" | grep -oE '(#|PR[-/]?)[0-9]+' 2>/dev/null | grep -oE '[0-9]+' || true)

    # チケットID: WORD-NNN 形式 (例: LINELOT_GR-123, USER-10)
    local ticket_ids
    ticket_ids=$(echo "$combined" | grep -oE '[A-Z][A-Z0-9_]+-[0-9]+' 2>/dev/null || true)

    # 抽出した識別子がなければチェック不要
    if [[ -z "$file_paths" && -z "$pr_numbers" && -z "$ticket_ids" ]]; then
        return 0
    fi

    # 在flightの足軽タスク (ashigaru[0-9]*.yaml) を走査
    for yaml_file in "$tasks_dir"/ashigaru[0-9]*.yaml; do
        [[ -f "$yaml_file" ]] || continue

        local status
        status=$(grep -E '^\s*status:' "$yaml_file" 2>/dev/null | head -1 \
                 | sed 's/.*status:[[:space:]]*//' | tr -d '"' | tr -d "'" | tr -d ' ')

        # assigned / blocked / in_progress のみ対象
        [[ "$status" == "assigned" || "$status" == "blocked" || "$status" == "in_progress" ]] || continue

        local agent_id task_id_inflight inflight_text
        agent_id=$(basename "$yaml_file" .yaml)
        task_id_inflight=$(grep -E '^\s*task_id:' "$yaml_file" 2>/dev/null | head -1 \
                           | sed 's/.*task_id:[[:space:]]*//' | tr -d '"' | tr -d "'")
        # target_path + description の先頭行を対象テキストとして取得
        inflight_text=$(grep -E '^\s*(target_path|description):' "$yaml_file" 2>/dev/null \
                        | head -5 | tr -d '"' | tr -d "'")

        # ファイルパス重複チェック
        if [[ -n "$file_paths" ]]; then
            while IFS= read -r fp; do
                [[ -z "$fp" ]] && continue
                if echo "$inflight_text" | grep -qF "$fp" 2>/dev/null; then
                    echo "🚨 [BLOCKED] RACE-001: 在flight足軽との対象重複を検知。委譲を中止します。" >&2
                    echo "   衝突先: ${agent_id} (task_id: ${task_id_inflight})" >&2
                    echo "   衝突対象: ファイルパス「${fp}」" >&2
                    echo "   委譲 purpose: $purpose" >&2
                    echo "   委譲 command: $command" >&2
                    echo "   ヒント: 衝突足軽のタスク完了後に再実行するか、対象が異なる場合は指定を明確化してください。" >&2
                    return 1
                fi
            done <<< "$file_paths"
        fi

        # PR番号重複チェック
        if [[ -n "$pr_numbers" ]]; then
            while IFS= read -r pr; do
                [[ -z "$pr" ]] && continue
                if echo "$inflight_text" | grep -qE "(#|PR[-/]?)${pr}([^0-9]|$)" 2>/dev/null; then
                    echo "🚨 [BLOCKED] RACE-001: 在flight足軽との対象重複を検知。委譲を中止します。" >&2
                    echo "   衝突先: ${agent_id} (task_id: ${task_id_inflight})" >&2
                    echo "   衝突対象: PR番号「#${pr}」" >&2
                    echo "   委譲 purpose: $purpose" >&2
                    echo "   委譲 command: $command" >&2
                    echo "   ヒント: 衝突足軽のタスク完了後に再実行するか、対象が異なる場合は指定を明確化してください。" >&2
                    return 1
                fi
            done <<< "$pr_numbers"
        fi

        # チケットID重複チェック
        if [[ -n "$ticket_ids" ]]; then
            while IFS= read -r tid; do
                [[ -z "$tid" ]] && continue
                if echo "$inflight_text" | grep -qF "$tid" 2>/dev/null; then
                    echo "🚨 [BLOCKED] RACE-001: 在flight足軽との対象重複を検知。委譲を中止します。" >&2
                    echo "   衝突先: ${agent_id} (task_id: ${task_id_inflight})" >&2
                    echo "   衝突対象: チケットID「${tid}」" >&2
                    echo "   委譲 purpose: $purpose" >&2
                    echo "   委譲 command: $command" >&2
                    echo "   ヒント: 衝突足軽のタスク完了後に再実行するか、対象が異なる場合は指定を明確化してください。" >&2
                    return 1
                fi
            done <<< "$ticket_ids"
        fi
    done

    return 0
}

if ! check_dedup_conflict "$PURPOSE" "$COMMAND"; then
    exit 1
fi

# ── Figma委譲ゲート (Layer2: 配賦元担保) ─────────────────────────
# [Layer2=配賦元担保。最終権威はLayer3=CI(H3)。Copilotはフックガード外ゆえ本ゲートで事前担保する。]
FIGMA_EMBED_NODE_ID=""
FIGMA_EMBED_URL=""

check_figma_gate() {
    local purpose="$1"
    local command="$2"
    local combined="$purpose $command"

    # Figma関連パスを抽出 (スラッシュ含む文字列)
    local paths
    paths=$(printf '%s' "$combined" | grep -oE '[a-zA-Z0-9_][a-zA-Z0-9_./-]*/[a-zA-Z0-9_./-]+' 2>/dev/null || true)

    # パスが抽出できない場合: 非UIタスクとみなしゲート素通り
    if [ -z "$paths" ]; then
        return 0
    fi

    # 抽出パスのいずれかがFigma-relevantか判定
    local figma_relevant=false
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        if is_figma_relevant_path "$p"; then
            figma_relevant=true
            break
        fi
    done <<< "$paths"

    if ! $figma_relevant; then
        return 0  # 非Figmaタスク: ゲート素通り
    fi

    # Figma-relevant: 48h以内の取得証跡を確認
    if ! has_fresh_evidence 48; then
        echo "🚨 [FIGMA-GATE BLOCKED] Figma-relevantなタスクの配賦を中止します。" >&2
        echo "   理由: 48時間以内のFigma取得証跡が見つかりません。" >&2
        echo "   (CopilotはPreToolUseフックガード外のため、配賦元での証跡担保が必須)" >&2
        echo "   対策: Figmaを取得後、証跡を記録してから再実行してください。" >&2
        return 1
    fi

    # 証跡あり: 正典node/URLをembedするため設定 (引数ENV優先, 次いでcanonical-map推定)
    local node_id="${FIGMA_NODE_ID:-}"
    local url="${FIGMA_URL:-}"

    if [ -z "$node_id" ]; then
        local canonical_map="$SHOGUN_ROOT/context/figma-canonical-map.md"
        if [ -f "$canonical_map" ]; then
            if printf '%s' "$combined" | grep -qiE '(tablet|タブレット)'; then
                node_id="4560:89033"
                url="https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:89033&m=dev"
            elif printf '%s' "$combined" | grep -qiE '(admin|管理|reservation|予約|raffle|抽選|user|ユーザ)'; then
                node_id="209:23439"
                url="https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=209:23439&m=dev"
            else
                node_id="要特定"
                url="要特定"
            fi
        else
            node_id="要特定"
            url="要特定"
        fi
    fi

    FIGMA_EMBED_NODE_ID="$node_id"
    FIGMA_EMBED_URL="$url"
    echo "[figma-gate] 証跡OK。正典node/URLをtask YAMLにembed: node=${FIGMA_EMBED_NODE_ID}" >&2
    return 0
}

if ! check_figma_gate "$PURPOSE" "$COMMAND"; then
    exit 1
fi

TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")

# タスクYAML atomic書き込み (tmp→mv でレース回避)
mkdir -p "$(dirname "$TASK_FILE")"
TASK_FILE_TMP="${TASK_FILE}.tmp.$$"
{
    printf 'task_id: "%s"\n' "$TASK_ID"
    printf 'agent: ashigaru_copilot\n'
    printf 'status: work\n'
    printf 'command: "%s"\n' "$COMMAND"
    printf 'purpose: "%s"\n' "$PURPOSE"
    printf 'project: "%s"\n' "$PROJECT"
    printf 'priority: %s\n' "$PRIORITY"
    printf 'timestamp: "%s"\n' "$TIMESTAMP"
    if [ -n "$FIGMA_EMBED_NODE_ID" ]; then
        printf '# Figma-gate embed: Copilotが自前取得せず参照できるよう正典node/URLを配賦時にembed\n'
        printf 'figma_node_id: "%s"\n' "$FIGMA_EMBED_NODE_ID"
        printf 'figma_url: "%s"\n' "$FIGMA_EMBED_URL"
    fi
    printf 'acceptance_criteria:\n'
    printf '  - "コマンドが正常に完了すること"\n'
    printf '  - "エラーが発生しないこと"\n'
} > "$TASK_FILE_TMP"
mv "$TASK_FILE_TMP" "$TASK_FILE"

echo "[assign] タスク割り当て完了: $TASK_FILE"

# Copilot足軽にinbox通知
if [ -f "$INBOX_WRITE" ]; then
    bash "$INBOX_WRITE" ashigaru_copilot \
        "タスクYAMLを読んで作業開始せよ。task_id: ${TASK_ID}" \
        task_assigned karo
    echo "[assign] inbox通知送信 → ashigaru_copilot"
fi

# ntfy通知（Copilotに作業依頼をプッシュ）
if [ -f "$NTFY_SCRIPT" ]; then
    bash "$NTFY_SCRIPT" "📋 [Copilot] タスク割当: ${TASK_ID} — ${PURPOSE}" 2>/dev/null || true
fi

# agmsg wake: copilotのmonitorを経由して確実着手を促す (fail-safe: 送信失敗してもタスク書込は既に成功)
bash ~/.agents/skills/agmsg/scripts/send.sh shogun shogun copilot \
    "${TASK_ID} を queue/tasks/ashigaru_copilot.yaml に配賦した。実行し完了を report+inbox(karo/gunshi)+agmsg(shogun) で報告せよ" || true

echo ""
echo "✅ Copilot足軽へのタスク割り当て完了"
echo "   task_id:  $TASK_ID"
echo "   purpose:  $PURPOSE"
echo "   project:  $PROJECT"
echo ""
