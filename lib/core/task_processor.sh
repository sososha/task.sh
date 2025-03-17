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
    # 最初のタスクかどうか確認
    if ! grep -q "^- [A-Z0-9][A-Z0-9][0-9]\{2\}:" "$details_file"; then
        # 最初のタスクの場合は空行を追加
        echo "" >> "$temp_file"
    fi
    echo "- ${task_id}:" >> "$temp_file"
    
    # 各フィールドの値を設定
    echo "  ${DETAIL_FIELDS[0]} ${DETAIL_SEPARATOR} ${details:-${task_name}の実装}" >> "$temp_file"
    echo "  ${DETAIL_FIELDS[1]} ${DETAIL_SEPARATOR} ${consideration:-未定}" >> "$temp_file"
    
    safe_update_file "$details_file" "$temp_file"
    return 0
}

# タスクファイルの構造を修復（タスク行の後に空行を確保）
repair_task_structure() {
    local task_file="$1"
    local temp_file=$(get_temp_file "repair_structure")
    
    # ファイルが存在しない場合は何もしない
    if [ ! -f "$task_file" ]; then
        debug_log "修復対象ファイルが存在しません: $task_file"
        return 1
    fi
    
    debug_log "タスク構造の修復を開始: $task_file"
    
    local prev_line=""
    local prev_is_task=false
    
    # ファイルを1行ずつ処理
    while IFS= read -r line || [[ -n "$line" ]]; do
        # タスク行の検出
        if [[ "$line" =~ ^-[[:space:]]*([A-Z0-9]+): ]]; then
            # 前の行もタスク行だった場合は、間に空行が必要
            if [ "$prev_is_task" = true ]; then
                echo "" >> "$temp_file"
                debug_log "連続するタスク行の間に空行を追加"
            fi
            
            # 現在のタスク行を出力
            echo "$line" >> "$temp_file"
            prev_is_task=true
            prev_line="$line"
            continue
        # 詳細行または他の行の処理
        else
            # 前の行がタスク行で、現在の行が空行でない詳細行の場合
            if [ "$prev_is_task" = true ] && [[ -n "$line" ]] && [[ "$line" =~ ^[[:space:]] ]]; then
                # タスク行と詳細行の間に空行を挿入
                echo "" >> "$temp_file"
                debug_log "タスク行と詳細行の間に空行を追加"
            fi
            
            # 現在の行を出力
            echo "$line" >> "$temp_file"
            prev_is_task=false
            prev_line="$line"
        fi
    done < "$task_file"
    
    # 変更を元のファイルに適用
    safe_update_file "$task_file" "$temp_file"
    debug_log "タスク構造の修復完了: $task_file"
    
    return 0
}

# タスク詳細を定義された順序で整理する
format_task_details() {
    local task_file="$1"
    local temp_file=$(get_temp_file "format_details")
    
    # ファイルが存在しない場合は何もしない
    if [ ! -f "$task_file" ]; then
        debug_log "修復対象ファイルが存在しません: $task_file"
        return 1
    fi
    
    debug_log "タスク詳細のフォーマットを開始: $task_file"
    
    # DETAIL_FIELDSが未定義の場合、デフォルト値を設定
    if [ -z "${DETAIL_FIELDS[*]:-}" ]; then
        DETAIL_FIELDS=("内容" "設計思想" "懸念" "実装結果" "結果的懸念")
    fi
    
    # DETAIL_SEPARATORが未定義の場合、デフォルト値を設定
    DETAIL_SEPARATOR="${DETAIL_SEPARATOR:-:}"
    
    # タスクファイルをセクションに分割して処理
    local tasks_temp=$(get_temp_file "tasks_section")
    local details_temp=$(get_temp_file "details_section")
    
    split_task_file "$task_file" "$tasks_temp" "$details_temp"
    
    # Tasksセクションをそのまま保持（末尾の余分な空行を除去）
    local last_non_empty_line=""
    local output_tasks=""
    
    while IFS= read -r line; do
        if [[ -n "$line" ]] || [[ -n "$last_non_empty_line" ]]; then
            if [[ -n "$last_non_empty_line" ]]; then
                output_tasks+="$last_non_empty_line"$'\n'
            fi
            last_non_empty_line="$line"
        fi
    done < "$tasks_temp"
    
    if [[ -n "$last_non_empty_line" ]]; then
        output_tasks+="$last_non_empty_line"$'\n'
    fi
    
    # Detailsの前に必ず1行だけ空行を入れる
    output_tasks+=$'\n'
    
    # Detailsヘッダーを追加
    output_tasks+="# Details"$'\n'
    output_tasks+="# 書式:"$'\n'
    output_tasks+="# ID: ${DETAIL_FIELDS[0]} ${DETAIL_SEPARATOR} ${DETAIL_FIELDS[1]} ${DETAIL_SEPARATOR} ${DETAIL_FIELDS[2]} ${DETAIL_SEPARATOR} ${DETAIL_FIELDS[3]} ${DETAIL_SEPARATOR} ${DETAIL_FIELDS[4]}"$'\n'
    
    # Tasks セクションからタスク情報を取得
    local task_ids=()
    local task_names=()
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*[${SYMBOL_COMPLETED}${SYMBOL_IN_PROGRESS}${SYMBOL_NOT_STARTED}][[:space:]]+([A-Z0-9][A-Z0-9][0-9]{2})[[:space:]]+(.+) ]]; then
            task_ids+=("${BASH_REMATCH[1]}")
            task_names+=("${BASH_REMATCH[2]}")
        fi
    done < "$tasks_temp"
    
    # 詳細セクションからタスク詳細を抽出
    # 連想配列の代わりに複数の配列を使用
    local task_detail_ids=()
    local task_detail_fields=()
    local task_detail_values=()
    local current_task=""
    
    while IFS= read -r line; do
        # タスク行を検出
        if [[ "$line" =~ ^-[[:space:]]*([A-Z0-9][A-Z0-9][0-9]{2}): ]]; then
            current_task="${BASH_REMATCH[1]}"
            continue
        fi
        
        # 現在のタスクの詳細フィールドを抽出
        if [ -n "$current_task" ] && [[ "$line" =~ ^[[:space:]]*([^${DETAIL_SEPARATOR}]+)${DETAIL_SEPARATOR}(.*) ]]; then
            local field=$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            local value=$(echo "${BASH_REMATCH[2]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            task_detail_ids+=("$current_task")
            task_detail_fields+=("$field")
            task_detail_values+=("$value")
        fi
    done < "$details_temp"
    
    # 各タスクの詳細セクションを生成
    local output_details=""
    local first_task=true
    for task_id in "${task_ids[@]}"; do
        # 最初のタスクの前だけ空行を入れる、それ以外は空行なし
        if [ "$first_task" = true ]; then
            output_details+=$'\n'
            first_task=false
        fi
        output_details+="- ${task_id}:"$'\n'
        
        local task_index=0
        for ((i=0; i<${#task_ids[@]}; i++)); do
            if [ "${task_ids[$i]}" = "$task_id" ]; then
                task_index=$i
                break
            fi
        done
        
        local task_name="${task_names[$task_index]}"
        local fields_found=false
        
        # 各フィールドを順番に出力
        for field in "${DETAIL_FIELDS[@]}"; do
            # このタスクIDとフィールドに対応する値を探す
            local value=""
            for ((j=0; j<${#task_detail_ids[@]}; j++)); do
                if [ "${task_detail_ids[$j]}" = "$task_id" ] && [ "${task_detail_fields[$j]}" = "$field" ]; then
                    value="${task_detail_values[$j]}"
                    break
                fi
            done
            
            if [ -n "$value" ]; then
                output_details+="  ${field} ${DETAIL_SEPARATOR} ${value}"$'\n'
                fields_found=true
            fi
        done
        
        # フィールドがない場合はデフォルト値を設定
        if [ "$fields_found" = false ]; then
            output_details+="  ${DETAIL_FIELDS[0]} ${DETAIL_SEPARATOR} ${task_name}の実装"$'\n'
            output_details+="  ${DETAIL_FIELDS[1]} ${DETAIL_SEPARATOR} 未定"$'\n'
        fi
    done
    
    # 最終的な出力をファイルに書き込む
    echo -n "$output_tasks" > "$temp_file"
    echo -n "$output_details" >> "$temp_file"
    
    # 更新を適用
    safe_update_file "$task_file" "$temp_file"
    
    debug_log "タスク詳細のフォーマット完了: $task_file"
    return 0
} 