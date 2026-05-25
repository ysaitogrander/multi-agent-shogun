#!/usr/bin/env bash
# =============================================================================
# install_shogun_cli.sh - shogunコマンドをグローバルにインストール
# =============================================================================
# 実行方法:
#   bash install_shogun_cli.sh
# =============================================================================

set -euo pipefail

SHOGUN_HOME_DEFAULT="/Users/yukihirosaito/Documents/line_raffle/multi-agent-shogun"
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}⚔️  shogun CLI インストーラー${NC}"
echo ""

# SHOGUN_HOMEの確認
if [[ -d "$SHOGUN_HOME_DEFAULT" ]]; then
  SHOGUN_HOME="$SHOGUN_HOME_DEFAULT"
  echo -e "${GREEN}✓${NC} SHOGUN_HOME: $SHOGUN_HOME"
else
  echo -e "${YELLOW}?${NC} multi-agent-shogunのパスを入力してください:"
  read -r SHOGUN_HOME
  if [[ ! -d "$SHOGUN_HOME" ]]; then
    echo "エラー: ディレクトリが見つかりません: $SHOGUN_HOME"
    exit 1
  fi
fi

# インストール先ディレクトリの作成
mkdir -p "$INSTALL_DIR"

# shogunスクリプトをコピーしてSHOGUN_HOMEを書き換え
SHOGUN_CLI="${SCRIPT_DIR}/shogun"
if [[ ! -f "$SHOGUN_CLI" ]]; then
  echo "エラー: shogunスクリプトが見つかりません: $SHOGUN_CLI"
  exit 1
fi

# SHOGUN_HOMEを実際のパスに書き換えてインストール
sed "s|SHOGUN_HOME:-/Users/yukihirosaito/Documents/line_raffle/multi-agent-shogun|SHOGUN_HOME:-${SHOGUN_HOME}|g" \
  "$SHOGUN_CLI" > "${INSTALL_DIR}/shogun"
chmod +x "${INSTALL_DIR}/shogun"

echo -e "${GREEN}✓${NC} インストール完了: ${INSTALL_DIR}/shogun"

# PATHの確認と追加
SHELL_RC=""
if [[ "$SHELL" == */zsh ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
  SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]]; then
  if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo "" >> "$SHELL_RC"
    echo "# shogun CLI" >> "$SHELL_RC"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    echo -e "${GREEN}✓${NC} PATHを追加しました: $SHELL_RC"
    echo ""
    echo -e "${YELLOW}⚠️  以下を実行してPATHを反映してください:${NC}"
    echo -e "   ${BLUE}source $SHELL_RC${NC}"
  else
    echo -e "${GREEN}✓${NC} PATH設定済み"
  fi
fi

echo ""
echo -e "${BOLD}インストール完了！${NC}"
echo ""
echo -e "使い方:"
echo -e "  ${BLUE}cd /your/project${NC}"
echo -e "  ${BLUE}shogun start${NC}   # チームを起動"
echo -e "  ${BLUE}shogun attach${NC}  # 将軍に接続"
echo -e "  ${BLUE}shogun status${NC}  # 状態確認"
echo -e "  ${BLUE}shogun stop${NC}    # 停止"
echo ""
