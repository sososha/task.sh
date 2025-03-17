#!/bin/bash
# task_processor.sh - タスク操作の共通処理

# 現在のスクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 依存するモジュールを読み込む
source "${SCRIPT_DIR}/file_utils.sh"

# デフォルト値の設定
SYMBOL_COMPLETED="${SYMBOL_COMPLETED:-✅}"
SYMBOL_IN_PROGRESS="${SYMBOL_IN_PROGRESS:-▣}"
SYMBOL_NOT_STARTED="${SYMBOL_NOT_STARTED:-□}"
DETAIL_SEPARATOR="${DETAIL_SEPARATOR:-:}"

# エラーメッセージを表示して終了する関数
error_exit() {
    echo "エラー: $1" >&2
    exit 1
}

# デバッグログを出力する関数
debug_log() {
    if [ "${DEBUG:-false}" = true ]; then
        echo "DEBUG: $1" >&2
    fi
}

# タスクファイルの存在をチェック
check_task_file() {
    if ! file_exists "$TASK_FILE"; then
        error_exit "タスクファイルが見つかりません。'task start'で初期化してください。"
    fi
}

# プロジェクトルートディレクトリを特定（.gitディレクトリがある場所）
get_project_root() {
    local current_dir="$PWD"
    while [ "$current_dir" != "/" ]; do
        if [ -d "${current_dir}/.git" ]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    echo "$PWD"  # .gitが見つからない場合は現在のディレクトリを使用
}

# タスクが存在するかチェック
task_exists() {
    local task_id="$1"
    if ! file_exists "$TASK_FILE"; then
        return 1
    fi
    grep -q "^[[:space:]]*[${SYMBOL_COMPLETED}${SYMBOL_IN_PROGRESS}${SYMBOL_NOT_STARTED}][[:space:]]*${task_id}" "$TASK_FILE"
}

# タスクのステータスを取得
get_task_status() {
    local task_id="$1"
    if ! task_exists "$task_id"; then
        return 1
    fi
    
    local line=$(grep "^[[:space:]]*[${SYMBOL_COMPLETED}${SYMBOL_IN_PROGRESS}${SYMBOL_NOT_STARTED}][[:space:]]*${task_id}" "$TASK_FILE")
    local symbol=$(echo "$line" | awk '{print $1}')
    
    case "$symbol" in
        "${SYMBOL_COMPLETED}") echo "完了" ;;
        "${SYMBOL_IN_PROGRESS}") echo "進行中" ;;
        "${SYMBOL_NOT_STARTED}") echo "未着手" ;;
        *) echo "未着手" ;;  # デフォルト
    esac
}

# タスクのインデントを取得
get_indent_for_task() {
    local task_id="$1"
    if ! task_exists "$task_id"; then
        echo ""
        return 1
    fi
    
    local line=$(grep "^[[:space:]]*[${SYMBOL_COMPLETED}${SYMBOL_IN_PROGRESS}${SYMBOL_NOT_STARTED}][[:space:]]*${task_id}" "$TASK_FILE")
    echo "$line" | sed 's/[^[:space:]].*$//'
}

# 親タスクに基づくインデントを計算
get_indent_for_parent() {
    local parent_id="$1"
    local parent_indent=$(get_indent_for_task "$parent_id")
    echo "${parent_indent}    "  # 子タスクは親より1レベル深く
}

# ステータスに応じた記号を取得
get_status_symbol() {
    case "$1" in
        "完了") echo "${SYMBOL_COMPLETED}" ;;
        "進行中") echo "${SYMBOL_IN_PROGRESS}" ;;
        "未着手") echo "${SYMBOL_NOT_STARTED}" ;;
        *) 
            echo "警告: 不明な状態「$1」です。「未着手」として扱います。" >&2
            echo "${SYMBOL_NOT_STARTED}" 
            ;;
    esac
}

# タスクに使用される次のIDを生成
generate_task_id() {
    local parent_id="${1:-}"
    local level_index=0
    
    # LEVELSが未定義の場合、デフォルト値を設定
    if [ -z "${LEVELS[*]:-}" ]; then
        LEVELS=("A" "B" "C" "D" "E")
    fi
    
    # PREFIXが未定義の場合、デフォルト値を設定
    PREFIX="${PREFIX:-P}"
    
    # NUMBER_FORMATが未定義の場合、デフォルト値を設定
    NUMBER_FORMAT="${NUMBER_FORMAT:-%02d}"
    
    if [ -z "$parent_id" ]; then
        # 最上位タスク
        level_index=0
    else
        # 親タスクから次のレベルを決定
        # 例: PA01 -> 次は PB
        if [ ${#parent_id} -ge 2 ]; then
            for ((i=0; i<${#LEVELS[@]}; i++)); do
                if [[ "${parent_id:1:1}" == "${LEVELS[$i]}" ]]; then
                    level_index=$((i + 1))
                    break
                fi
            done
            
            # 最大階層チェック
            if [ $level_index -ge ${#LEVELS[@]} ]; then
                echo "警告: 最大階層レベルに達しています。同じレベルで作成します。" >&2
                level_index=$((${#LEVELS[@]} - 1))
            fi
        else
            # 不正な親IDの場合は最上位タスクとして扱う
            level_index=0
        fi
    fi
    
    # 次のIDを生成
    local level="${LEVELS[$level_index]}"
    local next_num=$(get_next_number "${PREFIX}${level}")
    printf "%s%s$(echo $NUMBER_FORMAT)" "$PREFIX" "$level" "$next_num"
}

# 指定された接頭辞に対する次の番号を取得
get_next_number() {
    local prefix="$1"
    local pattern="^[[:space:]]*[^[:space:]]+[[:space:]]+${prefix}([0-9]+)"
    local max_num=0
    
    if ! file_exists "$TASK_FILE"; then
        echo 1
        return 0
    fi
    
    while IFS= read -r line; do
        if [[ "$line" =~ $pattern ]]; then
            local num="${BASH_REMATCH[1]}"
            if [ "$num" -gt "$max_num" ]; then
                max_num="$num"
            fi
        fi
    done < "$TASK_FILE"
    
    echo $((max_num + 1))
}

# タスクセクションを初期化
initialize_task_section() {
    local file="$1"
    
    cat > "$file" << EOF
# Tasks
# 凡例: ${SYMBOL_COMPLETED} = 完了, ${SYMBOL_IN_PROGRESS} = 進行中, ${SYMBOL_NOT_STARTED} = 未着手

EOF
}

# 詳細セクションを初期化
initialize_detail_section() {
    local file="$1"
    
    cat > "$file" << EOF
# Details
# 書式:
# ID: ${DETAIL_FIELDS[0]} ${DETAIL_SEPARATOR} ${DETAIL_FIELDS[1]} ${DETAIL_SEPARATOR} ${DETAIL_FIELDS[2]} ${DETAIL_SEPARATOR} ${DETAIL_FIELDS[3]} ${DETAIL_SEPARATOR} ${DETAIL_FIELDS[4]}
EOF
}

# ファイル内の空行を整理
sanitize_empty_lines() {
    local file="$1"
    local temp_file=$(get_temp_file "sanitize")
    
    # 連続した空行を1つにまとめる
    awk 'BEGIN { prev_empty = 0; } 
    {
        if (/^[[:space:]]*$/) {
            if (prev_empty == 0) {
                print "";
                prev_empty = 1;
            }
        } else {
            print $0;
            prev_empty = 0;
        }
    }' "$file" > "$temp_file"
    
    safe_update_file "$file" "$temp_file"
}

# タスクファイルを初期化
initialize_task_file() {
    if file_exists "$TASK_FILE"; then
        return 1
    fi
    
    ensure_dir "$(dirname "$TASK_FILE")"
    local tasks_temp=$(get_temp_file "tasks")
    local details_temp=$(get_temp_file "details")
    
    initialize_task_section "$tasks_temp"
    initialize_detail_section "$details_temp"
    
    merge_files "$TASK_FILE" "$tasks_temp" "$details_temp"
    
    rm -f "$tasks_temp" "$details_temp"
    
    return 0
}

# タスクを適切な位置に挿入
insert_task() {
    local tasks_file="$1"
    local name="$2"
    local symbol="$3"
    local id="$4"
    local indent="$5"
    local parent_id="$6"
    
    local temp_file=$(get_temp_file "insert_task")
    local found_parent=false
    local inserted=false
    
    if [ -z "$parent_id" ]; then
        # 最上位タスクを最後に追加
        cat "$tasks_file" > "$temp_file"
        echo "${symbol} ${id} ${name}" >> "$temp_file"
    else
        # 子タスクを親タスクの後に挿入
        while IFS= read -r line || [[ -n "$line" ]]; do
            # 親タスクを見つけた場合
            if [[ "$line" =~ .*"$parent_id".* ]] && ! $found_parent; then
                found_parent=true
                echo "$line" >> "$temp_file"
                continue
            fi
            
            # 親タスクの後の処理
            if $found_parent && ! $inserted; then
                # 現在の行のインデントを取得
                current_indent=$(echo "$line" | sed 's/[^ ].*//')
                current_indent_len=${#current_indent}
                indent_len=${#indent}
                parent_indent=$(get_indent_for_task "$parent_id")
                parent_indent_len=${#parent_indent}
                
                # 空行またはインデントレベルが浅い場合はタスクを挿入
                if [[ -z "$line" ]] || [[ $current_indent_len -le $parent_indent_len ]]; then
                    echo "${indent}${symbol} ${id} ${name}" >> "$temp_file"
                    inserted=true
                fi
            fi
            
            echo "$line" >> "$temp_file"
        done < "$tasks_file"
        
        # タスクがまだ挿入されていない場合は最後に追加
        if ! $inserted && $found_parent; then
            echo "${indent}${symbol} ${id} ${name}" >> "$temp_file"
        elif ! $found_parent; then
            # 親が見つからない場合はエラー
            rm -f "$temp_file"
            return 1
        fi
    fi
    
    safe_update_file "$tasks_file" "$temp_file"
    return 0
}

# 詳細情報を追加
add_task_detail() {
    local details_file="$1"
    local task_id="$2"
    local task_name="$3"
    local details="${4:-}"
    local consideration="${5:-}"
    
    # DETAIL_FIELDSが未定義の場合、デフォルト値を設定
    if [ -z "${DETAIL_FIELDS[*]:-}" ]; then
        DETAIL_FIELDS=("内容" "設計思想" "懸念" "実装結果" "結果的懸念")
    fi
    
    # DETAIL_SEPARATORが未定義の場合、デフォルト値を設定
    DETAIL_SEPARATOR="${DETAIL_SEPARATOR:-:}"
    
    local temp_file=$(get_temp_file "add_detail")
    cat "$details_file" > "$temp_file"
    
    # 詳細情報を追加
    echo "" >> "$temp_file"
    echo "- ${task_id}:" >> "$temp_file"
    
    # 各フィールドの値を設定
    for ((i=0; i<${#DETAIL_FIELDS[@]} && i<2; i++)); do
        local field="${DETAIL_FIELDS[$i]}"
        local value=""
        
        if [ $i -eq 0 ]; then
            value="${details:-${task_name}の実装}"
        elif [ $i -eq 1 ]; then
            value="${consideration:-未定}"
        else
            value=""
        fi
        
        echo "  ${field}${DETAIL_SEPARATOR}${value}" >> "$temp_file"
    done
    
    safe_update_file "$details_file" "$temp_file"
    return 0
} 