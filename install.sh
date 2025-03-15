#!/bin/bash
# Task Management ツールインストールスクリプト
set -euo pipefail

# バージョン
VERSION="1.0.0"

# カラー表示用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# インストール先ディレクトリ
DEFAULT_BIN_DIR="$HOME/bin"
DEFAULT_INSTALL_DIR="$HOME/.task-management"

# Usage表示
show_usage() {
    cat << EOF
Task Management ツール インストーラー v${VERSION}

使用方法: ./install.sh [オプション]

オプション:
  -h, --help              このヘルプを表示
  -b, --bin-dir <dir>     実行ファイルのインストール先 (デフォルト: $DEFAULT_BIN_DIR)
  -d, --dir <dir>         スクリプト一式のインストール先 (デフォルト: $DEFAULT_INSTALL_DIR)
  -l, --local             カレントディレクトリにシンボリックリンクを作成 (開発用)

例:
  ./install.sh                     # デフォルト設定でインストール
  ./install.sh -b /usr/local/bin   # 実行ファイルを/usr/local/binにインストール
EOF
}

# スクリプトのコピー元ディレクトリ（このスクリプトが存在するディレクトリ）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# デフォルト設定
BIN_DIR="$DEFAULT_BIN_DIR"
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
LOCAL_INSTALL=false

# コマンドライン引数の解析
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -b|--bin-dir)
            BIN_DIR="$2"
            shift 2
            ;;
        -d|--dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -l|--local)
            LOCAL_INSTALL=true
            shift
            ;;
        *)
            echo -e "${RED}エラー: 不明なオプション '$1'${NC}" >&2
            show_usage
            exit 1
            ;;
    esac
done

# ディレクトリが存在するか確認し、なければ作成
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}ディレクトリ '$dir' を作成します...${NC}"
        mkdir -p "$dir"
    fi
}

# メインのインストール処理
install_task_management() {
    echo -e "${GREEN}Task Management ツール v${VERSION} をインストールします...${NC}"
    
    if [ "$LOCAL_INSTALL" = true ]; then
        # ローカルインストール（シンボリックリンクのみ）
        echo -e "${YELLOW}ローカルインストールを実行します...${NC}"
        ensure_dir "$BIN_DIR"
        
        # シンボリックリンクを作成
        echo -e "${GREEN}シンボリックリンクを作成: $BIN_DIR/task -> $SCRIPT_DIR/task.sh${NC}"
        ln -sf "$SCRIPT_DIR/task.sh" "$BIN_DIR/task"
        
        # 実行権限を付与
        chmod +x "$SCRIPT_DIR/task.sh"
    else
        # 標準インストール
        # インストールディレクトリを作成
        ensure_dir "$INSTALL_DIR"
        ensure_dir "$BIN_DIR"
        
        # スクリプトをコピー
        echo -e "${GREEN}スクリプトをコピー: $SCRIPT_DIR/task.sh -> $INSTALL_DIR/task.sh${NC}"
        cp "$SCRIPT_DIR/task.sh" "$INSTALL_DIR/task.sh"
        
        # 実行権限を付与
        chmod +x "$INSTALL_DIR/task.sh"
        
        # シンボリックリンクを作成
        echo -e "${GREEN}シンボリックリンクを作成: $BIN_DIR/task -> $INSTALL_DIR/task.sh${NC}"
        ln -sf "$INSTALL_DIR/task.sh" "$BIN_DIR/task"
        
        # README/ドキュメントをコピー
        if [ -f "$SCRIPT_DIR/README.md" ]; then
            echo -e "${GREEN}ドキュメントをコピー: $SCRIPT_DIR/README.md -> $INSTALL_DIR/README.md${NC}"
            cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/README.md"
        fi
    fi
    
    # PATHの確認
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo -e "${YELLOW}警告: $BIN_DIR がPATHに含まれていません${NC}"
        echo -e "${YELLOW}次のコマンドをシェル設定ファイル(.bashrc, .zshrc等)に追加することを検討してください:${NC}"
        echo -e "${YELLOW}  export PATH=\"\$PATH:$BIN_DIR\"${NC}"
    fi
    
    echo -e "${GREEN}インストールが完了しました!${NC}"
    echo -e "${GREEN}使用方法: task help${NC}"
}

# インストール実行
install_task_management

exit 0 