#!/bin/bash
# task.sh - シンプルなタスク管理ツール
# 厳格モードを有効化
set -euo pipefail

# 現在のスクリプトディレクトリを取得
# macOSとLinuxの両方で動作するシンボリックリンク解決方法
resolve_symlink() {
    local path="$1"
    local resolved_path="$path"
    
    # シンボリックリンクを解決
    while [ -L "$resolved_path" ]; do
        local target="$(readlink "$resolved_path")"
        if [ "${target:0:1}" = "/" ]; then
            # 絶対パス
            resolved_path="$target"
        else
            # 相対パス
            resolved_path="$(dirname "$resolved_path")/$target"
        fi
    done
    
    echo "$resolved_path"
}

SCRIPT_PATH="$(resolve_symlink "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# グローバル変数
VERSION="2.0.0"
DEBUG=false

# プロジェクトディレクトリ設定
LIB_DIR="${SCRIPT_DIR}/lib"
TASKS_DIR="${SCRIPT_DIR}/tasks"
TASK_FILE="${TASKS_DIR}/tasks"
TEMPLATES_DIR="${TASKS_DIR}/templates"
CURRENT_TEMPLATE="${TEMPLATES_DIR}/current_template.yaml"
TEMP_DIR="/tmp/task_manager"

# ライブラリモジュールの読み込み
source "${LIB_DIR}/core/file_utils.sh"
source "${LIB_DIR}/core/task_processor.sh"
source "${LIB_DIR}/template/template_manager.sh"
source "${LIB_DIR}/commands/task_commands.sh"
source "${LIB_DIR}/commands/template_commands.sh"

# ヘルプドキュメント表示
show_help() {
    cat << EOF
タスク管理ツール v${VERSION} - 使用方法：

task start                                 # タスク管理を開始
task purge                                # タスクファイルを完全削除
task add <タスク名> <状態>                   # タスクを追加
     [内容] [設計思想] [親タスクID]         # 内容と設計思想、親タスクはオプション
task batch <ファイル>                       # 一括操作の実行
task update <タスクID> <新状態>             # タスク状態を更新
task update-detail <ID> <フィールド> <値>   # タスク詳細を更新
task update-detail-safe <ID> <フィールド> <値> # 安全にタスク詳細を更新
task delete <ID>                           # タスクを削除
task list [ID] [--status <状態>]           # タスク一覧表示
task format                               # タスク詳細のフォーマットを整理
task template list                        # テンプレート一覧表示
task template show <テンプレート名>         # テンプレートの内容を表示
task template use <テンプレート名>          # テンプレートを使用
task template create <テンプレート名>       # 新しいテンプレートを作成
task template edit <テンプレート名>         # テンプレートを編集
task template import <ファイル>             # テンプレートをインポート
task template export <テンプレート名> <ファイル> # テンプレートをエクスポート
task help                                 # このヘルプを表示

状態: 完了, 進行中, 未着手
フィールド: テンプレートによって定義（デフォルト: 内容, 設計思想, 懸念, 実装結果, 結果的懸念）

オプション:
  -v, --verbose                           # 詳細なログを出力
  -d, --debug                             # デバッグモードを有効化

一括操作のフォーマット:
  + [親タスク] タスク名 | 状態 | 内容 | 設計思想  # タスク追加
  - タスクID                               # タスク削除
  = タスクID | 新状態                       # 状態更新
  * タスクID | フィールド | 値               # 詳細更新
EOF
}

# バージョン情報の表示
show_version() {
    echo "タスク管理ツール v${VERSION}"
}

# 引数のパース
parse_args() {
    # デバッグオプションの確認
    for arg in "$@"; do
        if [ "$arg" = "-v" ] || [ "$arg" = "--verbose" ] || [ "$arg" = "-d" ] || [ "$arg" = "--debug" ]; then
            DEBUG=true
            debug_log "デバッグモード有効"
        fi
    done
    
    # 引数がない場合はヘルプを表示
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    # コマンドの実行
    local command="$1"
    shift
    
    case "$command" in
        "start")
            cmd_start
            ;;
        "purge")
            cmd_purge
            ;;
        "add")
            cmd_add "$@"
            ;;
        "batch")
            cmd_batch "$@"
            ;;
        "update")
            cmd_update "$@"
            ;;
        "update-detail")
            cmd_update_detail "$@"
            ;;
        "update-detail-safe")
            cmd_update_detail_safe "$@"
            ;;
        "delete")
            cmd_delete "$@"
            ;;
        "list")
            cmd_list "$@"
            ;;
        "format")
            cmd_format
            ;;
        "template")
            handle_template_command "$@"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        "version"|"--version"|"-V")
            show_version
            ;;
        *)
            error_exit "未知のコマンド: $command\nヘルプを表示するには: $0 help"
            ;;
    esac
    
    return $?
}

# メイン処理の実行
parse_args "$@"
exit $? 