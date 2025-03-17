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
    if [ ! -d "$1" ]; then
        mkdir -p "$1" || return 1
    fi
    return 0
}

# ファイルを分割（Tasks セクションと Details セクション）
split_task_file() {
    local input_file="$1"
    local tasks_file="$2"
    local details_file="$3"
    
    # ファイルが存在しない場合は空ファイルを作成して終了
    if [ ! -f "$input_file" ]; then
        > "$tasks_file"
        > "$details_file"
        return 0
    fi
    
    if [ "${DEBUG:-false}" = true ]; then
        echo "DEBUG: split_task_file - 入力ファイル: $input_file" >&2
        echo "DEBUG: split_task_file - 入力ファイル内容:" >&2
        cat "$input_file" >&2
    fi
    
    # Detailsセクションの開始行を検索
    local details_start=$(grep -n "^# Details" "$input_file" | head -1 | cut -d':' -f1)
    
    if [ -z "$details_start" ]; then
        # Detailsセクションが見つからない場合はすべてをタスクセクションとして扱う
        cat "$input_file" > "$tasks_file"
        > "$details_file"
    else
        # タスクセクション（1行目からDetails行の前まで）を抽出
        head -n $((details_start - 1)) "$input_file" > "$tasks_file"
        
        # 詳細セクション（Details行から最後まで）を抽出
        tail -n +${details_start} "$input_file" > "$details_file"
    fi
    
    if [ "${DEBUG:-false}" = true ]; then
        echo "DEBUG: split_task_file - タスクファイル内容:" >&2
        cat "$tasks_file" >&2
        echo "DEBUG: split_task_file - 詳細ファイル内容:" >&2
        cat "$details_file" >&2
    fi
    
    return 0
}

# ファイルを結合
merge_files() {
    local output_file="$1"
    shift
    
    # 出力ファイルを初期化
    > "$output_file"
    
    # 入力ファイルをすべて結合
    for file in "$@"; do
        if [ -f "$file" ]; then
            cat "$file" >> "$output_file"
        fi
    done
}

# 一時ファイルパスを生成
get_temp_file() {
    local prefix="${1:-temp}"
    mktemp "/tmp/${prefix}_XXXXXXXX"
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
    local original_file="$1"
    local temp_file="$2"
    local backup_file="${original_file}.bak"
    
    # バックアップを作成
    cp "$original_file" "$backup_file" 2>/dev/null || true
    
    # 新しい内容を適用
    cat "$temp_file" > "$original_file"
    
    if [ $? -ne 0 ]; then
        # 更新に失敗した場合はバックアップを復元
        if [ -f "$backup_file" ]; then
            mv "$backup_file" "$original_file"
        fi
        return 1
    fi
    
    # バックアップを削除
    rm -f "$backup_file"
    
    # デバッグ用：ファイルの内容を表示
    if [ "${DEBUG:-false}" = true ]; then
        echo "DEBUG: 更新後のファイル内容:" >&2
        cat "$original_file" >&2
    fi
    
    return 0
} 