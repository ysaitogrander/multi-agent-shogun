#!/usr/bin/env bash
# lib/copilot_safety.sh — 共有安全ゲート関数 (source 専用ライブラリ)
#
# ═══════════════════════════════════════════════════════════════
# CONTRACT (T2/T3 利用者向け)
# ═══════════════════════════════════════════════════════════════
#
# 使い方:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/copilot_safety.sh"
#   if ! validate_command "$cmd"; then exit 1; fi
#   warn_external_api "$cmd"
#
# ─── validate_command ──────────────────────────────────────────
#   引数 : $1 — 検証対象のコマンド文字列
#   返値 : 0  — 安全 (BAN 未検知)
#          1  — BAN 検知 (呼出側が exit を判断)
#   副作用: BAN 検知時のみ stderr へ警告を出力
#   保証  : 関数定義の副作用なし・複数 source 安全 (冪等)
#   検知  : CLAUDE.md Destructive Operation Safety D001-D008 完全対応
#            D001/D002 危険 rm -rf / D003 git push --force(--force-with-lease 除外)
#            D004 git reset --hard / git clean -f / git checkout -- . / git restore .
#            D005 sudo/su/chmod -R/chown -R / D006 kill/killall/pkill/tmux kill-*
#            D007 mkfs/dd if=/fdisk/mount/umount / D008 curl|bash / wget|sh
#
# ─── warn_external_api ─────────────────────────────────────────
#   引数 : $1 — 検証対象のコマンド文字列
#   返値 : 常に 0 (警告のみ・委譲は継続)
#   副作用: Figma/外部API語検知時のみ stderr へ警告を出力
# ═══════════════════════════════════════════════════════════════

validate_command() {
    local cmd="$1"

    # D001/D002: 危険な rm -rf (システムパス / プロジェクト外)
    if echo "$cmd" | grep -qE '\brm\b[[:space:]]+-[rRfF]*f[rRfF]*[[:space:]]*(\/|~[^/]|~$|\/mnt\/|\/home\/|\/usr\/|\/etc\/|\/var\/|\/sys\/|\/dev\/)' || \
       echo "$cmd" | grep -qE '\brm\b[[:space:]]+-[rRfF]*r[rRfF]*[[:space:]].*-[rRfF]*f[rRfF]*[[:space:]]*(\/|~)'; then
        echo "🚨 [BLOCKED] D001/D002: 危険な rm -rf パターン検知。委譲を中止します。" >&2
        echo "   command: $cmd" >&2
        return 1
    fi

    # D003: git push --force / -f (--force-with-lease なし)
    if echo "$cmd" | grep -qE '\bgit\b.*\bpush\b.*(--force\b|\s-f\b)' && \
       ! echo "$cmd" | grep -qE '\bgit\b.*\bpush\b.*--force-with-lease'; then
        echo "🚨 [BLOCKED] D003: git push --force/-f (--force-with-lease なし) 検知。委譲を中止します。" >&2
        echo "   command: $cmd" >&2
        return 1
    fi

    # D004: git reset --hard
    if echo "$cmd" | grep -qE '\bgit\b.*\breset\b.*--hard'; then
        echo "🚨 [BLOCKED] D004: git reset --hard 検知。委譲を中止します。" >&2
        echo "   command: $cmd" >&2
        return 1
    fi

    # D004: git clean -f
    if echo "$cmd" | grep -qE '\bgit\b.*\bclean\b.*-[a-zA-Z]*f'; then
        echo "🚨 [BLOCKED] D004: git clean -f 検知。委譲を中止します。" >&2
        echo "   command: $cmd" >&2
        return 1
    fi

    # D004: git checkout -- .
    if echo "$cmd" | grep -qE '\bgit\b.*\bcheckout\b.*--[[:space:]]+\.'; then
        echo "🚨 [BLOCKED] D004: git checkout -- . 検知。委譲を中止します。" >&2
        echo "   command: $cmd" >&2
        return 1
    fi

    # D004: git restore .
    if echo "$cmd" | grep -qE '\bgit\b.*\brestore\b[[:space:]]+\.'; then
        echo "🚨 [BLOCKED] D004: git restore . 検知。委譲を中止します。" >&2
        echo "   command: $cmd" >&2
        return 1
    fi

    # D005: sudo / su / chmod -R / chown -R
    if echo "$cmd" | grep -qE '\bsudo\b|\bsu[[:space:]]|\bsu$'; then
        echo "🚨 [BLOCKED] D005: sudo/su 検知。委譲を中止します。" >&2
        echo "   command: $cmd" >&2
        return 1
    fi
    if echo "$cmd" | grep -qE '\bchmod[[:space:]]+-R\b|\bchown[[:space:]]+-R\b'; then
        echo "🚨 [BLOCKED] D005: chmod -R / chown -R 検知。委譲を中止します。" >&2
        echo "   command: $cmd" >&2
        return 1
    fi

    # D006: kill / killall / pkill / tmux kill-*
    if echo "$cmd" | grep -qE '\b(kill|killall|pkill)\b'; then
        echo "🚨 [BLOCKED] D006: kill/killall/pkill 検知。委譲を中止します。" >&2
        echo "   command: $cmd" >&2
        return 1
    fi
    if echo "$cmd" | grep -qE '\btmux\b.*(kill-server|kill-session|kill-window|kill-pane)'; then
        echo "🚨 [BLOCKED] D006: tmux kill-* 検知。委譲を中止します。" >&2
        echo "   command: $cmd" >&2
        return 1
    fi

    # D007: mkfs / dd if= / fdisk / mount / umount
    if echo "$cmd" | grep -qE '\b(mkfs|fdisk|umount)\b|\bdd[[:space:]]+if=|\bmount[[:space:]]+'; then
        echo "🚨 [BLOCKED] D007: 危険なディスク操作コマンド (mkfs/dd/fdisk/mount/umount) 検知。委譲を中止します。" >&2
        echo "   command: $cmd" >&2
        return 1
    fi

    # D008: パイプ to シェル (curl/wget | bash/sh)
    if echo "$cmd" | grep -qE '(curl|wget)[^|]*\|[[:space:]]*(bash|sh)\b'; then
        echo "🚨 [BLOCKED] D008: パイプtoシェルパターン (curl/wget | bash/sh) 検知。委譲を中止します。" >&2
        echo "   command: $cmd" >&2
        return 1
    fi

    return 0
}

# A703-1: Figma/外部API語の警告 (copilot は guardrail 外ゆえ不割当原則)
warn_external_api() {
    local cmd="$1"
    if echo "$cmd" | grep -qiE '\bfigma\b|mcp__figma|外部[Aa][Pp][Ii]|external[_-]?api'; then
        echo "⚠️  [WARNING] A703-1: COMMANDにFigma/外部API語を検知。" >&2
        echo "   Copilotはguardrail外ゆえFigma/外部APIタスクの不割当が原則 (A703-1)。" >&2
        echo "   誤割当の可能性があります。意図的な場合はタスク設計を再確認してください。" >&2
        echo "   委譲は継続しますが、軍師/家老のレビューを強く推奨します。" >&2
        echo "" >&2
    fi
}
