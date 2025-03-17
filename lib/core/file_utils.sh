#!/bin/bash
# file_utils.sh - ファイル操作ユーティリティ

# OS検出
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "linux"
    fi
}

# sedコマンドのOS依存の違いを吸収
sed_inplace() {
    local file="$1"
    local pattern="$2"
    
    if [ "$(detect_os)" == "macos" ]; then
        sed -i '' "$pattern" "$file"
    else
        sed -i "$pattern" "$file"
    fi
}

# ファイルが存在するか確認
file_exists() {
    [ -f "$1" ]
}

# ディレクトリが存在するか確認
dir_exists() {
    [ -d "$1" ]
}

# ディレクトリを作成（存在しない場合）
ensure_dir() {
    local dir="$1"
    if ! dir_exists "$dir"; then
        mkdir -p "$dir"
    fi
}

# ファイルを分割（Tasks セクションと Details セクション）
split_task_file() {
    local input_file="$1"
    local tasks_file="$2"
    local details_file="$3"
    
    local in_details=false
    
    > "$tasks_file"  # 空のファイルを作成
    > "$details_file"  # 空のファイルを作成
    
    if ! file_exists "$input_file"; then
        return 1
    fi
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "# Details"* ]]; then
            in_details=true
            echo "$line" >> "$details_file"
        elif [[ "$in_details" == true ]]; then
            echo "$line" >> "$details_file"
        else
            echo "$line" >> "$tasks_file"
        fi
    done < "$input_file"
    
    # 詳細セクションがない場合は作成
    if [[ "$in_details" == false ]]; then
        cat >> "$details_file" << EOF

# Details
# 書式:
# ID: 内容 : 設計思想 : 懸念 : 実装結果 : 結果的懸念
EOF
    fi
    
    return 0
}

# ファイルを結合
merge_files() {
    local output_file="$1"
    shift
    
    > "$output_file"  # 空のファイルを作成
    
    for file in "$@"; do
        if file_exists "$file"; then
            cat "$file" >> "$output_file"
        fi
    done
    
    return 0
}

# 一時ファイルパスを生成
get_temp_file() {
    local prefix="${1:-tmp}"
    local temp_dir="${TEMP_DIR:-/tmp}"
    ensure_dir "$temp_dir"
    echo "${temp_dir}/${prefix}_$(date +%s)_$RANDOM.tmp"
}

# 一時ディレクトリを作成
create_temp_dir() {
    local prefix="${1:-tmpdir}"
    local temp_base="${TEMP_DIR:-/tmp}"
    local temp_dir="${temp_base}/${prefix}_$(date +%s)_$RANDOM"
    ensure_dir "$temp_dir"
    echo "$temp_dir"
}

# 初期化済みファイル作成
create_initialized_file() {
    local file="$1"
    local template="$2"
    
    if ! file_exists "$file"; then
        ensure_dir "$(dirname "$file")"
        if [ -n "$template" ] && file_exists "$template"; then
            cp "$template" "$file"
        else
            > "$file"
        fi
        return 0
    fi
    
    return 1  # ファイルが既に存在する
}

# ファイルを安全に更新
safe_update_file() {
    local target="$1"
    local temp="$2"
    
    if ! file_exists "$temp"; then
        return 1
    fi
    
    # バックアップ作成（オプション）
    if [ "${BACKUP_ENABLED:-false}" = true ]; then
        local backup="${target}.bak"
        if file_exists "$target"; then
            cp "$target" "$backup"
        fi
    fi
    
    # ファイル更新
    mv "$temp" "$target"
    return 0
} 