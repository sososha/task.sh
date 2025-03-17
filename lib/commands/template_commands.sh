#!/bin/bash
# template_commands.sh - テンプレート関連コマンド

# 現在のスクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 依存するモジュールを読み込む
source "${SCRIPT_DIR}/../core/file_utils.sh"
source "${SCRIPT_DIR}/../template/template_manager.sh"

# テンプレート一覧を表示
cmd_template_list() {
    # テンプレートディレクトリの存在確認
    if ! dir_exists "$TEMPLATES_DIR"; then
        error_exit "テンプレートディレクトリが見つかりません: $TEMPLATES_DIR"
    fi
    
    echo "利用可能なテンプレート:"
    
    # 利用可能なテンプレートを取得
    local templates=()
    while IFS= read -r template; do
        templates+=("$template")
    done < <(get_available_templates "$TEMPLATES_DIR" "$CURRENT_TEMPLATE")
    
    # 現在のテンプレート名を取得
    local current_template_name=""
    if file_exists "$CURRENT_TEMPLATE"; then
        current_template_name=$(get_template_value "$CURRENT_TEMPLATE" "name" "")
    fi
    
    # テンプレート一覧を表示
    for template in "${templates[@]}"; do
        local template_file="${TEMPLATES_DIR}/${template}.yaml"
        local description=$(get_template_value "$template_file" "description" "")
        
        if [ "$template" = "$current_template_name" ]; then
            echo "* $template: $description (現在使用中)"
        else
            echo "- $template: $description"
        fi
    done
    
    return 0
}

# テンプレートの内容を表示
cmd_template_show() {
    if [ $# -lt 1 ]; then
        error_exit "使用法: $0 template show <テンプレート名>"
    fi
    
    local template_name="$1"
    local template_file="${TEMPLATES_DIR}/${template_name}.yaml"
    
    if ! file_exists "$template_file"; then
        error_exit "テンプレート '$template_name' が見つかりません"
    fi
    
    echo "テンプレート '$template_name' の内容:"
    cat "$template_file"
    
    return 0
}

# テンプレートを使用
cmd_template_use() {
    if [ $# -lt 1 ]; then
        error_exit "使用法: $0 template use <テンプレート名>"
    fi
    
    local template_name="$1"
    
    # 現在のテンプレートを設定
    set_current_template "$template_name" "$TEMPLATES_DIR" "$CURRENT_TEMPLATE"
    
    echo "テンプレート '$template_name' を使用するように設定しました"
    return 0
}

# 新しいテンプレートを作成
cmd_template_create() {
    if [ $# -lt 1 ]; then
        error_exit "使用法: $0 template create <テンプレート名>"
    fi
    
    local template_name="$1"
    local template_file="${TEMPLATES_DIR}/${template_name}.yaml"
    
    if file_exists "$template_file"; then
        error_exit "テンプレート '$template_name' は既に存在します"
    fi
    
    # テンプレートを作成
    create_custom_template "$template_file" "$template_name"
    
    echo "新しいテンプレート '$template_name' を作成しました"
    echo "テンプレートをカスタマイズするには次のコマンドを使用します:"
    echo "$0 template edit $template_name"
    
    return 0
}

# テンプレートを編集
cmd_template_edit() {
    if [ $# -lt 1 ]; then
        error_exit "使用法: $0 template edit <テンプレート名>"
    fi
    
    local template_name="$1"
    local template_file="${TEMPLATES_DIR}/${template_name}.yaml"
    
    if ! file_exists "$template_file"; then
        error_exit "テンプレート '$template_name' が見つかりません"
    fi
    
    # デフォルトエディタでテンプレートを開く
    ${EDITOR:-vi} "$template_file"
    
    echo "テンプレート '$template_name' を編集しました"
    return 0
}

# テンプレートのインポート
cmd_template_import() {
    if [ $# -lt 1 ]; then
        error_exit "使用法: $0 template import <ファイル>"
    fi
    
    local import_file="$1"
    
    if ! file_exists "$import_file"; then
        error_exit "インポートファイル '$import_file' が見つかりません"
    fi
    
    # ファイル名からテンプレート名を取得
    local template_name=$(basename "$import_file" .yaml)
    local template_file="${TEMPLATES_DIR}/${template_name}.yaml"
    
    # 既存テンプレートの確認
    if file_exists "$template_file"; then
        echo "警告: テンプレート '$template_name' は既に存在します"
        read -p "上書きしますか？(yes/N): " confirm
        
        if [ "$confirm" != "yes" ]; then
            echo "インポートをキャンセルしました"
            return 0
        fi
    fi
    
    # テンプレートをインポート
    ensure_dir "$TEMPLATES_DIR"
    cp "$import_file" "$template_file"
    
    echo "テンプレート '$template_name' をインポートしました"
    return 0
}

# テンプレートのエクスポート
cmd_template_export() {
    if [ $# -lt 2 ]; then
        error_exit "使用法: $0 template export <テンプレート名> <出力ファイル>"
    fi
    
    local template_name="$1"
    local export_file="$2"
    local template_file="${TEMPLATES_DIR}/${template_name}.yaml"
    
    if ! file_exists "$template_file"; then
        error_exit "テンプレート '$template_name' が見つかりません"
    fi
    
    # 出力ディレクトリの存在確認
    local export_dir=$(dirname "$export_file")
    ensure_dir "$export_dir"
    
    # テンプレートをエクスポート
    cp "$template_file" "$export_file"
    
    echo "テンプレート '$template_name' を '$export_file' にエクスポートしました"
    return 0
}

# テンプレートコマンドの実行
handle_template_command() {
    if [ $# -lt 1 ]; then
        cmd_template_list
        return $?
    fi
    
    local subcommand="$1"
    shift
    
    case "$subcommand" in
        "list")
            cmd_template_list "$@"
            ;;
        "show")
            cmd_template_show "$@"
            ;;
        "use")
            cmd_template_use "$@"
            ;;
        "create")
            cmd_template_create "$@"
            ;;
        "edit")
            cmd_template_edit "$@"
            ;;
        "import")
            cmd_template_import "$@"
            ;;
        "export")
            cmd_template_export "$@"
            ;;
        *)
            error_exit "不明なテンプレートコマンド: $subcommand\nヘルプを表示するには: $0 help"
            ;;
    esac
    
    return $?
} 