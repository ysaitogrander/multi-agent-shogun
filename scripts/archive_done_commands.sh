#!/usr/bin/env bash
# archive_done_commands.sh — 後方互換ラッパー。実体は archive_done_cmds.sh に移行済み。
# 既存参照 (karo_role workflow step11.8 等) のために本ファイルを維持する。
exec "$(dirname "${BASH_SOURCE[0]}")/archive_done_cmds.sh" "$@"
exit $?

# ==== 旧実装 (参照用・実行されない) ====
# archive_done_commands.sh — shogun_to_karo.yaml の done/cancelled コマンドを自動アーカイブ
#
# 目的:
#   - queue/shogun_to_karo.yaml から status=done/cancelled のコマンドを
#     queue/shogun_to_karo_archive.yaml へ移動し、アクティブファイルを軽量化
#   - トークン消費削減（7-8万トークン→数千トークンへ）
#
# 実行タイミング:
#   1. 手動実行: bash scripts/archive_done_commands.sh
#   2. 定期実行: cron (推奨: 週1回 or 月1回)
#   3. Karoからの呼び出し: cleanup処理の一環として
#
# 安全保証:
#   - バックアップ自動作成（.bak）
#   - 件数検証（移動前後で総数一致を確認）
#   - YAML構文検証（PyYAML でパース確認）
#   - 失敗時は自動ロールバック

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUE_DIR="$SCRIPT_DIR/queue"
SRC_FILE="$QUEUE_DIR/shogun_to_karo.yaml"
ARCHIVE_FILE="$QUEUE_DIR/shogun_to_karo_archive.yaml"
BACKUP_FILE="$SRC_FILE.bak"
LOG_FILE="$SCRIPT_DIR/logs/archive_done_commands.log"

# Python (PyYAML 必須)
PY="${PYTHON:-$SCRIPT_DIR/.venv/bin/python3}"
[ -x "$PY" ] || PY="python3"

# ログ出力
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" | tee -a "$LOG_FILE"
}

# エラーハンドリング
error_exit() {
    log "ERROR: $1"
    if [ -f "$BACKUP_FILE" ]; then
        log "Restoring from backup..."
        cp "$BACKUP_FILE" "$SRC_FILE"
        log "Rollback completed. Original file restored."
    fi
    exit 1
}

# メイン処理
main() {
    log "=== Archive Done Commands - START ==="

    # 前提チェック
    [ -f "$SRC_FILE" ] || error_exit "Source file not found: $SRC_FILE"
    command -v "$PY" >/dev/null 2>&1 || error_exit "Python not found: $PY"

    # 処理前の件数確認
    local total_before
    total_before=$(grep -c '^  - id: cmd_' "$SRC_FILE" || echo 0)
    log "Total commands before: $total_before"

    # 5件未満なら実行スキップ（done/cancelledが少ない = アーカイブ不要）
    if [ "$total_before" -lt 5 ]; then
        log "Total commands < 5. Skipping archive (not needed)."
        log "=== Archive Done Commands - SKIPPED ==="
        return 0
    fi

    # バックアップ作成
    log "Creating backup..."
    cp "$SRC_FILE" "$BACKUP_FILE" || error_exit "Failed to create backup"

    # Python スクリプトで分割実行
    log "Running archive script..."
    "$PY" - <<'PYTHON' || error_exit "Archive script failed"
import sys
import re
from pathlib import Path

src = Path("queue/shogun_to_karo.yaml")
archive = Path("queue/shogun_to_karo_archive.yaml")

# 元ファイル読み込み
lines = src.read_text(encoding="utf-8").splitlines(keepends=True)

# preamble（commands: 行まで）を抽出
start = next(i for i, l in enumerate(lines) if re.match(r'^  - id: cmd_', l))
preamble = lines[:start]

# ブロック分割
idxs = [i for i, l in enumerate(lines) if re.match(r'^  - id: cmd_', l)]
idxs.append(len(lines))
blocks = [lines[idxs[k]:idxs[k+1]] for k in range(len(idxs)-1)]

# status 判定関数
def status_of(block):
    for line in block:
        m = re.match(r'^    status:\s*(\S+)', line)
        if m:
            return m.group(1)
    return None

# done/cancelled を分離
keep = [b for b in blocks if status_of(b) not in ("done", "cancelled")]
arch = [b for b in blocks if status_of(b) in ("done", "cancelled")]

print(f"total={len(blocks)} keep={len(keep)} archive={len(arch)}", file=sys.stderr)

# 件数検証
if len(keep) + len(arch) != len(blocks):
    print(f"ERROR: Count mismatch! {len(keep)} + {len(arch)} != {len(blocks)}", file=sys.stderr)
    sys.exit(1)

# archiveが0件なら実行不要
if len(arch) == 0:
    print("No done/cancelled commands found. Nothing to archive.", file=sys.stderr)
    sys.exit(0)

# アクティブファイル更新
src.write_text("".join(preamble) + "".join("".join(b) for b in keep), encoding="utf-8")

# アーカイブファイル更新（既存ファイルがあれば追記）
if archive.exists():
    # 既存archiveから既存ブロックを読み込み
    arch_lines = archive.read_text(encoding="utf-8").splitlines(keepends=True)
    arch_start = next((i for i, l in enumerate(arch_lines) if re.match(r'^  - id: cmd_', l)), len(arch_lines))
    arch_preamble = arch_lines[:arch_start] if arch_start < len(arch_lines) else ["commands:\n"]
    arch_existing = arch_lines[arch_start:] if arch_start < len(arch_lines) else []
    # 新規ブロックを追記
    archive.write_text("".join(arch_preamble) + "".join(arch_existing) + "".join("".join(b) for b in arch), encoding="utf-8")
else:
    # 新規作成
    archive.write_text("commands:\n" + "".join("".join(b) for b in arch), encoding="utf-8")

print(f"SUCCESS: {len(arch)} commands archived", file=sys.stderr)
PYTHON

    # 処理後の件数確認
    local active_after archive_count
    active_after=$(grep -c '^  - id: cmd_' "$SRC_FILE" || echo 0)
    archive_count=$(grep -c '^  - id: cmd_' "$ARCHIVE_FILE" || echo 0)
    
    log "Active commands after: $active_after"
    log "Archive total: $archive_count"

    # YAML構文検証
    log "Validating YAML syntax..."
    "$PY" -c "import yaml; yaml.safe_load(open('$SRC_FILE')); yaml.safe_load(open('$ARCHIVE_FILE'))" \
        || error_exit "YAML validation failed"

    log "YAML validation passed"

    # バックアップ削除
    rm -f "$BACKUP_FILE"
    log "Backup removed (success)"

    log "=== Archive Done Commands - COMPLETED ==="
    log "Summary: $total_before total → $active_after active + archived"
}

# 実行
main "$@"
