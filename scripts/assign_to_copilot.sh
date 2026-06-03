#!/usr/bin/env bash
# assign_to_copilot.sh — KaroがCopilot足軽にタスクを割り当てるヘルパー
# (Karo/Shogunが手動で呼ぶか、Claude側のスクリプトから呼ぶ)
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

# ── バリデーション実行 (書込前) ──────────────────────────────────
if ! validate_command "$COMMAND"; then
    exit 1
fi
warn_external_api "$COMMAND"

TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")

# タスクYAML atomic書き込み (tmp→mv でレース回避)
mkdir -p "$(dirname "$TASK_FILE")"
TASK_FILE_TMP="${TASK_FILE}.tmp.$$"
cat > "$TASK_FILE_TMP" << EOF
task_id: "${TASK_ID}"
agent: ashigaru_copilot
status: work
command: "${COMMAND}"
purpose: "${PURPOSE}"
project: "${PROJECT}"
priority: ${PRIORITY}
timestamp: "${TIMESTAMP}"
acceptance_criteria:
  - "コマンドが正常に完了すること"
  - "エラーが発生しないこと"
EOF
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

echo ""
echo "✅ Copilot足軽へのタスク割り当て完了"
echo "   task_id:  $TASK_ID"
echo "   purpose:  $PURPOSE"
echo "   project:  $PROJECT"
echo ""
