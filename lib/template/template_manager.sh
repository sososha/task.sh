#!/bin/bash
# template_manager.sh - テンプレート操作の共通処理

# 現在のスクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 依存するモジュールを読み込む
source "${SCRIPT_DIR}/../core/file_utils.sh"
source "${SCRIPT_DIR}/template_parser.sh"

# グローバル変数の初期化（テンプレート設定用）
init_template_globals() {
    # デフォルト値
    PREFIX="P"
    LEVELS=("A" "B" "C" "D")
    NUMBER_FORMAT="%02d"
    SYMBOL_COMPLETED="✅"
    SYMBOL_IN_PROGRESS="▣"
    SYMBOL_NOT_STARTED="□"
    DETAIL_SEPARATOR=" : "
    DETAIL_FIELDS=("内容" "設計思想" "懸念" "実装結果" "結果的懸念")
}

# テンプレートファイルから設定を読み込む
load_template() {
    local template_file="$1"
    
    if ! file_exists "$template_file"; then
        echo "警告: テンプレートファイルが見つかりません。デフォルト値を使用します。" >&2
        init_template_globals
        return 1
    fi
    
    # テンプレート名
    TEMPLATE_NAME=$(get_template_value "$template_file" "name" "default")
    
    # インデックス設定
    PREFIX=$(get_template_value "$template_file" "prefix" "P")
    
    # レベル配列を読み込み
    LEVELS=()
    while IFS= read -r level; do
        LEVELS+=("$level")
    done < <(get_template_array "$template_file" "levels")
    
    if [ ${#LEVELS[@]} -eq 0 ]; then
        LEVELS=("A" "B" "C" "D")
    fi
    
    # 番号フォーマット
    NUMBER_FORMAT=$(get_template_value "$template_file" "number_format" "%02d")
    
    # 進捗状態の記号
    SYMBOL_COMPLETED=$(get_template_value "$template_file" "symbol_completed" "✅")
    SYMBOL_IN_PROGRESS=$(get_template_value "$template_file" "symbol_in_progress" "▣")
    SYMBOL_NOT_STARTED=$(get_template_value "$template_file" "symbol_not_started" "□")
    
    # 詳細情報の設定
    DETAIL_SEPARATOR=$(get_template_value "$template_file" "separator" " : ")
    
    # フィールド名を配列で取得
    DETAIL_FIELDS=()
    while IFS= read -r field; do
        DETAIL_FIELDS+=("$field")
    done < <(get_template_array "$template_file" "fields")
    
    if [ ${#DETAIL_FIELDS[@]} -eq 0 ]; then
        DETAIL_FIELDS=("内容" "設計思想" "懸念" "実装結果" "結果的懸念")
    fi
    
    return 0
}

# デフォルトテンプレートを作成
create_default_template() {
    local file="$1"
    ensure_dir "$(dirname "$file")"
    
    cat > "$file" <<EOF
name: "default"
description: "デフォルトのタスク管理テンプレート"
version: "1.0"

task_template:
  # インデックスの設定
  index:
    prefix: "P"
    levels: ["A", "B", "C", "D"]
    number_format: "%02d"

  # 進捗状態の設定
  status_symbols:
    completed: "✅"
    in_progress: "▣"
    not_started: "□"

  # 詳細情報の設定
  details:
    separator: " : "
    fields:
      - name: "内容"
        default: "\${task_name}の実装"
      - name: "設計思想"
        default: "未定"
      - name: "懸念"
        default: ""
      - name: "実装結果"
        default: ""
      - name: "結果的懸念"
        default: ""
EOF
}

# シンプルテンプレートを作成
create_simple_template() {
    local file="$1"
    ensure_dir "$(dirname "$file")"
    
    cat > "$file" <<EOF
name: "simple"
description: "シンプルなタスク管理テンプレート"
version: "1.0"

task_template:
  # インデックスの設定
  index:
    prefix: "T"
    levels: ["1", "2", "3"]
    number_format: "%d"

  # 進捗状態の設定
  status_symbols:
    completed: "✓"
    in_progress: ">"
    not_started: "-"

  # 詳細情報の設定
  details:
    separator: " | "
    fields:
      - name: "内容"
        default: "\${task_name}"
      - name: "メモ"
        default: ""
      - name: "期限"
        default: ""
EOF
}

# 新しいテンプレートを作成
create_custom_template() {
    local file="$1"
    local name="$2"
    ensure_dir "$(dirname "$file")"
    
    cat > "$file" <<EOF
name: "$name"
description: "カスタムテンプレート"
version: "1.0"

task_template:
  # インデックスの設定
  index:
    prefix: "C"
    levels: ["1", "2", "3", "4"]
    number_format: "%03d"

  # 進捗状態の設定
  status_symbols:
    completed: "✓"
    in_progress: "○"
    not_started: "×"

  # 詳細情報の設定
  details:
    separator: " | "
    fields:
      - name: "内容"
        default: "\${task_name}"
      - name: "備考"
        default: ""
EOF
}

# 現在のテンプレートを設定
set_current_template() {
    local template_name="$1"
    local templates_dir="$2"
    local current_template="$3"
    
    if [ ! -d "$templates_dir" ]; then
        error_exit "テンプレートディレクトリが見つかりません: $templates_dir"
    fi
    
    local template_file="${templates_dir}/${template_name}.yaml"
    if [ ! -f "$template_file" ]; then
        echo "テンプレート '$template_name' が見つかりません。デフォルトテンプレートを使用します。" >&2
        template_name="default"
        template_file="${templates_dir}/default.yaml"
        
        # デフォルトテンプレートもない場合は作成
        if [ ! -f "$template_file" ]; then
            create_default_template "$template_file"
        fi
    fi
    
    # 現在のテンプレートを設定
    cp "$template_file" "$current_template"
    
    # テンプレート設定を読み込む
    load_template "$current_template"
    
    return 0
}

# 利用可能なテンプレート一覧を取得
get_available_templates() {
    local templates_dir="$1"
    local current_template="$2"
    
    if [ ! -d "$templates_dir" ]; then
        return 1
    fi
    
    local templates=()
    
    for template in "$templates_dir"/*.yaml; do
        if [ -f "$template" ]; then
            local name=$(basename "$template" .yaml)
            templates+=("$name")
        fi
    done
    
    # 一覧を出力
    for template in "${templates[@]}"; do
        echo "$template"
    done
    
    return 0
}

# テンプレートを初期化
initialize_templates() {
    local templates_dir="$1"
    local current_template="$2"
    
    # テンプレートディレクトリを作成
    ensure_dir "$templates_dir"
    
    # デフォルトとシンプルテンプレートを作成
    create_default_template "${templates_dir}/default.yaml"
    create_simple_template "${templates_dir}/simple.yaml"
    
    # 現在のテンプレートを設定
    set_current_template "default" "$templates_dir" "$current_template"
    
    return 0
} 