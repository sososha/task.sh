#!/bin/bash
# template_parser.sh - YAML形式のテンプレートをパースする

# 現在のスクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 依存するモジュールを読み込む
source "${SCRIPT_DIR}/../core/file_utils.sh"

# シンプルなYAMLパーサー（基本的な構造のみサポート）
parse_yaml_value() {
    local file="$1"
    local key="$2"
    
    if ! file_exists "$file"; then
        return 1
    fi
    
    # キーを含む行を取得し、値を抽出
    local value=$(grep "^[[:space:]]*${key}:" "$file" | head -n 1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
    
    if [ -z "$value" ]; then
        # サブキーで検索
        value=$(grep -A 1 "${key}:" "$file" | tail -n 1 | sed 's/^[[:space:]]*//' | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
    fi
    
    echo "$value"
    return 0
}

# YAMLの配列を取得
parse_yaml_array() {
    local file="$1"
    local key="$2"
    
    if ! file_exists "$file"; then
        return 1
    fi
    
    # 配列と思われる行を見つけて値を抽出
    local line_num=$(grep -n "^[[:space:]]*${key}:" "$file" | cut -d: -f1)
    if [ -z "$line_num" ]; then
        return 1
    fi
    
    # 行の下にある配列要素を取得（インデントが深いもの）
    local line_indent=$(sed -n "${line_num}p" "$file" | sed 's/[^ ].*//')
    local indent_len=${#line_indent}
    local values=()
    
    # 次の行からインデントが深い行を順に取得
    local i=$((line_num + 1))
    local line
    
    while IFS= read -r line; do
        local current_indent=$(echo "$line" | sed 's/[^ ].*//')
        local current_indent_len=${#current_indent}
        
        # インデントが浅くなったら終了
        if [[ ! "$line" =~ ^[[:space:]]+ ]] || [ $current_indent_len -le $indent_len ]; then
            break
        fi
        
        # - で始まる行を配列要素として処理
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+ ]]; then
            local value=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
            values+=("$value")
        fi
    done < <(tail -n +$i "$file")
    
    # 配列を返す
    if [ ${#values[@]} -gt 0 ]; then
        for value in "${values[@]}"; do
            echo "$value"
        done
    fi
    
    return 0
}

# テンプレートのフィールド配列を取得
parse_template_fields() {
    local file="$1"
    
    if ! file_exists "$file"; then
        return 1
    fi
    
    local field_section=$(grep -n "fields:" "$file" | cut -d: -f1)
    if [ -z "$field_section" ]; then
        # デフォルトのフィールドを返す
        echo "内容"
        echo "設計思想"
        echo "懸念"
        echo "実装結果"
        echo "結果的懸念"
        return 0
    fi
    
    # fieldsセクション以降を取得
    local fields=()
    local in_fields=false
    local prev_indent=0
    
    while IFS= read -r line; do
        # fieldsセクションの開始
        if [[ "$line" =~ fields: ]]; then
            in_fields=true
            prev_indent=$(echo "$line" | sed 's/[^ ].*//')
            prev_indent="${prev_indent}  "  # 予想される子要素のインデント
            continue
        fi
        
        if $in_fields; then
            # 現在の行のインデントを取得
            local current_indent=$(echo "$line" | sed 's/[^ ].*//')
            
            # インデントが浅くなったら終了
            if [[ ! "$line" =~ ^[[:space:]]+ ]] || [ ${#current_indent} -lt ${#prev_indent} ]; then
                break
            fi
            
            # name: フィールドを取得
            if [[ "$line" =~ name: ]]; then
                local field=$(echo "$line" | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
                fields+=("$field")
            fi
        fi
    done < <(tail -n +$field_section "$file")
    
    # フィールドを返す
    if [ ${#fields[@]} -gt 0 ]; then
        for field in "${fields[@]}"; do
            echo "$field"
        done
    else
        # フィールドが取得できなかった場合はデフォルト値を返す
        echo "内容"
        echo "設計思想"
        echo "懸念"
        echo "実装結果"
        echo "結果的懸念"
    fi
    
    return 0
}

# テンプレートの指定部分を配列として取得
get_template_array() {
    local template_file="$1"
    local section="$2"
    
    if ! file_exists "$template_file"; then
        return 1
    fi
    
    case "$section" in
        "levels")
            parse_yaml_array "$template_file" "levels"
            ;;
        "fields")
            parse_template_fields "$template_file"
            ;;
        *)
            return 1
            ;;
    esac
    
    return 0
}

# テンプレートから指定されたキーの値を取得
get_template_value() {
    local template_file="$1"
    local key="$2"
    local default_value="$3"
    
    if ! file_exists "$template_file"; then
        echo "$default_value"
        return 1
    fi
    
    local value=""
    
    case "$key" in
        "name")
            value=$(parse_yaml_value "$template_file" "name")
            ;;
        "description")
            value=$(parse_yaml_value "$template_file" "description")
            ;;
        "prefix")
            value=$(parse_yaml_value "$template_file" "prefix")
            ;;
        "number_format")
            value=$(parse_yaml_value "$template_file" "number_format")
            ;;
        "separator")
            value=$(parse_yaml_value "$template_file" "separator")
            ;;
        "symbol_completed")
            value=$(parse_yaml_value "$template_file" "completed")
            ;;
        "symbol_in_progress")
            value=$(parse_yaml_value "$template_file" "in_progress")
            ;;
        "symbol_not_started")
            value=$(parse_yaml_value "$template_file" "not_started")
            ;;
        *)
            echo "$default_value"
            return 1
            ;;
    esac
    
    if [ -z "$value" ]; then
        echo "$default_value"
    else
        echo "$value"
    fi
    
    return 0
} 