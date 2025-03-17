#!/bin/bash
# task_commands.sh - タスク関連コマンド

# 現在のスクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 依存するモジュールを読み込む
source "${SCRIPT_DIR}/../core/file_utils.sh"
source "${SCRIPT_DIR}/../core/task_processor.sh"

# タスク管理を開始
cmd_start() {
    if file_exists "$TASK_FILE"; then
        echo "タスクファイルが既に存在します。"
        echo "以下のオプションがあります:"
        echo "  1) 新しいタスクを追加 → task add または task batch を使用"
        echo "  2) 全てのタスクを削除 → task purge を使用"
        return 0
    fi
    
    # タスクディレクトリとテンプレートディレクトリを作成
    ensure_dir "$TASKS_DIR"
    ensure_dir "$TEMPLATES_DIR"
    
    # テンプレートを初期化
    initialize_templates "$TEMPLATES_DIR" "$CURRENT_TEMPLATE"
    
    # テンプレート設定を読み込む
    load_template "$CURRENT_TEMPLATE"
    
    # タスクファイルを初期化
    initialize_task_file
    
    echo "タスク管理を開始しました"
    echo "次のコマンドでタスクを追加できます: task add"
    
    return 0
}

# タスクファイルを完全削除
cmd_purge() {
    if ! file_exists "$TASK_FILE"; then
        error_exit "タスクファイルが存在しません"
    fi
    
    echo "警告: この操作は全てのタスクを完全に削除します"
    echo "削除されたタスクは復元できません"
    read -p "本当に全てのタスクを削除しますか？(yes/N): " confirm
    
    if [ "$confirm" = "yes" ]; then
        rm -f "$TASK_FILE"
        echo "タスクファイルを完全に削除しました"
    else
        echo "操作をキャンセルしました"
    fi
    
    return 0
}

# タスクを追加
cmd_add() {
    if [ $# -lt 2 ]; then
        error_exit "使用法: $0 add <タスク名> <状態> [内容] [設計上の考慮] [親タスクID]"
    fi
    
    local name="$1"
    local status="$2"
    local details="${3:-${name}の実装}"
    local consideration="${4:-未定}"
    local parent_id="${5:-}"
    
    # テンプレート設定を読み込む
    load_template "$CURRENT_TEMPLATE"
    
    # タスクファイルが存在しない場合は初期化
    if ! file_exists "$TASK_FILE"; then
        initialize_task_file
    else
        # タスク構造を修復（タスク行の後に空行を確保）
        repair_task_structure "$TASK_FILE"
    fi
    
    # ステータスに応じた記号を設定
    local symbol=$(get_status_symbol "$status")
    
    # インデントとIDの設定
    local indent=""
    local id=""
    
    if [ -n "$parent_id" ]; then
        # 親タスクの存在確認
        if ! task_exists "$parent_id"; then
            error_exit "親タスクID '$parent_id' が見つかりません"
        fi
        # インデント設定
        indent=$(get_indent_for_parent "$parent_id")
        # ID生成
        id=$(generate_task_id "$parent_id")
    else
        # 最上位タスク
        id=$(generate_task_id)
    fi
    
    # ファイルを分割して処理
    local tasks_temp=$(get_temp_file "tasks")
    local details_temp=$(get_temp_file "details")
    
    split_task_file "$TASK_FILE" "$tasks_temp" "$details_temp"
    
    # タスクを追加
    if ! insert_task "$tasks_temp" "$name" "$symbol" "$id" "$indent" "$parent_id"; then
        error_exit "タスクの追加に失敗しました"
    fi
    
    # 詳細を追加
    if ! add_task_detail "$details_temp" "$id" "$name" "$details" "$consideration"; then
        error_exit "詳細情報の追加に失敗しました"
    fi
    
    # ファイルを結合
    local temp_file=$(get_temp_file "merged")
    merge_files "$temp_file" "$tasks_temp" "$details_temp"
    
    # 空行を整理
    sanitize_empty_lines "$temp_file"
    
    # 更新を適用
    safe_update_file "$TASK_FILE" "$temp_file"
    
    # 一時ファイルを削除
    rm -f "$tasks_temp" "$details_temp"
    
    echo "タスク '$name' (ID: $id) を追加しました"
    return 0
}

# タスクの状態を更新
cmd_update() {
    if [ $# -lt 2 ]; then
        error_exit "使用法: task update <タスクID> <新状態>"
    fi
    
    local task_id="$1"
    local status="$2"
    
    # テンプレート設定を読み込む
    load_template "$CURRENT_TEMPLATE"
    
    # シンボル変数のデフォルト値設定
    SYMBOL_COMPLETED="${SYMBOL_COMPLETED:-✅}"
    SYMBOL_IN_PROGRESS="${SYMBOL_IN_PROGRESS:-▣}"
    SYMBOL_NOT_STARTED="${SYMBOL_NOT_STARTED:-□}"
    
    # タスクファイルの存在を確認
    check_task_file
    
    # タスク構造を修復（タスク行の後に空行を確保）
    repair_task_structure "$TASK_FILE"
    
    # タスクの存在を確認
    if ! task_exists "$task_id"; then
        error_exit "タスクID '$task_id' が見つかりません"
    fi
    
    # 新しい状態記号を取得
    local symbol=$(get_status_symbol "$status")

    # 1. Tasksセクションの開始行を特定
    local tasks_start=$(grep -n "^# Tasks" "$TASK_FILE" | head -1 | cut -d':' -f1)
    if [ -z "$tasks_start" ]; then
        error_exit "タスクファイル内にTasksセクションが見つかりません"
    fi
    
    # 2. Detailsセクションの開始行（またはファイル終端）を特定
    local details_start=$(grep -n "^# Details" "$TASK_FILE" | head -1 | cut -d':' -f1)
    if [ -z "$details_start" ]; then
        details_start=$(wc -l < "$TASK_FILE")
    fi
    
    # 3. Tasksセクション内のタスク行を検索
    local task_line=$(sed -n "${tasks_start},${details_start}p" "$TASK_FILE" | 
                     grep -n "[[:space:]]*[^[:space:]][^[:space:]]*[[:space:]]*${task_id}[[:space:]]" | 
                     head -1 | cut -d':' -f1)
    
    if [ -z "$task_line" ]; then
        error_exit "Tasksセクション内にタスクID '$task_id' が見つかりません"
    fi
    
    # 実際のファイル内の行番号を計算
    task_line=$((tasks_start + task_line - 1))
    
    # 4. 一時ファイルで処理
    local temp_file=$(get_temp_file "update")
    
    # 5. タスク行の状態を更新（最初の非空白文字を置換）
    sed "${task_line}s/[^[:space:]][^[:space:]]*/\\${symbol}/" "$TASK_FILE" > "$temp_file"
    
    # 6. 更新を適用
    safe_update_file "$TASK_FILE" "$temp_file"
    
    echo "タスク '$task_id' の状態を '$status' に更新しました"
    return 0
}

# Detailsセクションのフォーマットを修正
fix_details_format() {
    local temp_file=$(get_temp_file "fix_details")
    
    awk '
    BEGIN { in_details = 0; }
    {
        # セクションの検出
        if ($0 ~ /^# Details/) {
            in_details = 1;
            print $0;
            next;
        }
        
        # Detailsセクション内のタスクID行を修正
        if (in_details && $0 ~ /^[^[:space:]].*:$/) {
            # 行の最初の文字が "-" でない場合は修正
            if ($0 !~ /^-/) {
                # 正規表現でタスクIDを抽出
                task_id = "";
                if (match($0, /[A-Z0-9][A-Z0-9][0-9][0-9]:/)) {
                    # マッチした部分の前後の位置を取得
                    start = RSTART;
                    len = RLENGTH - 1;  # コロンを除く
                    # タスクIDを抽出
                    task_id = substr($0, start, len);
                    print "- " task_id ":";
                } else {
                    print $0;  # 修正できない場合はそのまま出力
                }
            } else {
                print $0;  # 既に "-" で始まっていればそのまま出力
            }
        } else {
            print $0;  # その他の行はそのまま出力
        }
    }' "$TASK_FILE" > "$temp_file"
    
    # 更新を適用
    safe_update_file "$TASK_FILE" "$temp_file"
    return 0
}

# タスク詳細を更新
cmd_update_detail() {
    if [ $# -lt 3 ]; then
        error_exit "使用法: $0 update-detail <タスクID> <フィールド> <値>"
    fi
    
    local task_id="$1"
    local field_arg="$2"
    local value="$3"
    
    # デバッグ情報
    echo "タスクID: '$task_id'"
    echo "入力フィールド: '$field_arg'"
    echo "値: '$value'"
    
    # テンプレート設定を読み込む
    load_template "$CURRENT_TEMPLATE"
    
    # デフォルトフィールドを設定
    local default_fields=("内容" "設計思想" "懸念" "実装結果" "結果的懸念")
    
    # DETAIL_FIELDSが空または未定義の場合はデフォルト値を使用
    if [ -z "${DETAIL_FIELDS[*]:-}" ]; then
        DETAIL_FIELDS=("${default_fields[@]}")
    fi
    
    echo "有効なフィールド: ${DETAIL_FIELDS[*]}"
    
    # DETAIL_SEPARATORのデフォルト値設定
    DETAIL_SEPARATOR="${DETAIL_SEPARATOR:-:}"
    
    # タスクファイルの存在を確認
    check_task_file
    
    # タスク構造を修復（タスク行の後に空行を確保）
    repair_task_structure "$TASK_FILE"
    
    # タスクの存在を確認
    if ! task_exists "$task_id"; then
        error_exit "タスクID '$task_id' が見つかりません"
    fi
    
    # フィールド名を確認
    local valid_field=""
    for field_name in "${DETAIL_FIELDS[@]}"; do
        if [ "$field_name" = "$field_arg" ]; then
            valid_field="$field_name"
            break
        fi
    done
    
    if [ -z "$valid_field" ]; then
        echo "有効なフィールド: ${DETAIL_FIELDS[*]}"
        error_exit "不正なフィールド名: $field_arg"
    fi
    
    # グレップベースの効率的なアプローチを使用する
    
    # 1. タスク行の行番号を取得
    local task_line=$(grep -n "^- *${task_id}:" "$TASK_FILE" | cut -d':' -f1)
    if [ -z "$task_line" ]; then
        error_exit "タスクID '$task_id' がファイル内で見つかりません"
    fi
    
    # 2. 次のタスク行またはファイル終端までの範囲を特定
    local next_task_line=$(tail -n "+$((task_line + 1))" "$TASK_FILE" | grep -n "^-" | head -1 | cut -d':' -f1)
    if [ -n "$next_task_line" ]; then
        next_task_line=$((task_line + next_task_line - 1))
    else
        # 次のタスクが見つからない場合はファイルの末尾まで
        next_task_line=$(wc -l < "$TASK_FILE")
    fi
    
    # 3. 該当範囲内でフィールドが存在するか確認
    local field_exists=false
    local field_line=$(sed -n "${task_line},${next_task_line}p" "$TASK_FILE" | grep -n "^ *${valid_field} *${DETAIL_SEPARATOR}" | head -1 | cut -d':' -f1)
    
    if [ -n "$field_line" ]; then
        field_exists=true
        field_line=$((task_line + field_line - 1))
    fi
    
    local temp_file=$(get_temp_file "update_detail")
    
    # 4. フィールドが存在する場合は更新、存在しない場合は追加
    if [ "$field_exists" = true ]; then
        # フィールド行を更新
        sed "${field_line}s/^ *${valid_field} *${DETAIL_SEPARATOR}.*/  ${valid_field} ${DETAIL_SEPARATOR} ${value}/" "$TASK_FILE" > "$temp_file"
        echo "タスク '$task_id' の $valid_field を '$value' に更新しました"
    else
        # フィールドを追加（タスク行の直後に挿入）
        sed "${task_line}a\\  ${valid_field} ${DETAIL_SEPARATOR} ${value}" "$TASK_FILE" > "$temp_file"
        echo "タスク '$task_id' に $valid_field: $value を追加しました"
    fi
    
    # 5. 更新を適用
    safe_update_file "$TASK_FILE" "$temp_file"
    
    return 0
}

# タスクを削除
cmd_delete() {
    if [ $# -lt 1 ]; then
        error_exit "使用法: $0 delete <タスクID>"
    fi
    
    local task_id="$1"
    
    # テンプレート設定を読み込む
    load_template "$CURRENT_TEMPLATE"
    
    # タスクファイルの存在を確認
    check_task_file
    
    # タスク構造を修復（タスク行の後に空行を確保）
    repair_task_structure "$TASK_FILE"
    
    # タスクの存在を確認
    if ! task_exists "$task_id"; then
        error_exit "タスクID '$task_id' が見つかりません"
    fi
    
    # 一時ファイルで処理
    local temp_file=$(get_temp_file "delete")
    
    # タスク行と詳細行を削除
    local in_task_detail=false
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # タスク行をスキップ
        if [[ "$line" =~ [${SYMBOL_COMPLETED}${SYMBOL_IN_PROGRESS}${SYMBOL_NOT_STARTED}][[:space:]]*"$task_id" ]]; then
            continue
        fi
        
        # タスク詳細の開始を検出
        if [[ "$line" =~ ^-[[:space:]]*"$task_id": ]]; then
            in_task_detail=true
            continue
        fi
        
        # タスク詳細内の行をスキップ
        if [ "$in_task_detail" = true ]; then
            # 行の先頭にスペースがなければ詳細セクションの終了
            if [[ ! "$line" =~ ^[[:space:]] ]] && [[ -n "$line" ]]; then
                in_task_detail=false
            else
                continue
            fi
        fi
        
        echo "$line" >> "$temp_file"
    done < "$TASK_FILE"
    
    # 空行を整理
    sanitize_empty_lines "$temp_file"
    
    # 更新を適用
    safe_update_file "$TASK_FILE" "$temp_file"
    
    echo "タスク '$task_id' を削除しました"
    return 0
}

# タスク一覧を表示
cmd_list() {
    # テンプレート設定を読み込む
    load_template "$CURRENT_TEMPLATE"
    
    # シンボル変数のデフォルト値設定
    SYMBOL_COMPLETED="${SYMBOL_COMPLETED:-✅}"
    SYMBOL_IN_PROGRESS="${SYMBOL_IN_PROGRESS:-▣}"
    SYMBOL_NOT_STARTED="${SYMBOL_NOT_STARTED:-□}"
    
    # タスクファイルの存在を確認
    check_task_file
    
    # タスク構造を修復（タスク行の後に空行を確保）
    repair_task_structure "$TASK_FILE"
    
    local target_id="${1:-}"
    local status_filter="${2:-}"
    
    # ヘッダー（凡例）を表示
    echo "# 凡例: ${SYMBOL_COMPLETED} = 完了, ${SYMBOL_IN_PROGRESS} = 進行中, ${SYMBOL_NOT_STARTED} = 未着手"
    echo ""
    
    # タスクを表示
    local prev_level=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([[:space:]]*)([${SYMBOL_COMPLETED}${SYMBOL_IN_PROGRESS}${SYMBOL_NOT_STARTED}])[[:space:]]+([A-Z0-9][A-Z0-9][0-9]{2})[[:space:]]+(.+) ]]; then
            local indent="${BASH_REMATCH[1]}"
            local symbol="${BASH_REMATCH[2]}"
            local task_id="${BASH_REMATCH[3]}"
            local task_name="${BASH_REMATCH[4]}"
            
            # インデントレベルを計算（4スペース = 1レベル）
            local current_level=$((${#indent} / 4))
            
            # ステータスフィルターが指定されている場合、一致するもののみ表示
            if [ -n "$status_filter" ]; then
                if ! echo "$symbol" | grep -q "$status_filter"; then
                    continue
                fi
            fi
            
            # 特定のIDが指定されている場合、そのタスクとその子タスクのみ表示
            if [ -n "$target_id" ]; then
                if [[ ! "$task_id" =~ ^$target_id ]]; then
                    continue
                fi
            fi
            
            # タスク行を表示
            echo "$indent$symbol $task_id $task_name"
            
            # 詳細情報を取得して表示
            display_task_details "$task_id" "$indent"
            
            prev_level=$current_level
        fi
    done < <(grep -v "^#" "$TASK_FILE" | grep "^[[:space:]]*[${SYMBOL_COMPLETED}${SYMBOL_IN_PROGRESS}${SYMBOL_NOT_STARTED}]")
    
    return 0
}

# タスク詳細を表示
display_task_details() {
    local task_id="$1"
    local indent="$2"
    
    # DETAIL_SEPARATORのデフォルト値設定
    DETAIL_SEPARATOR="${DETAIL_SEPARATOR:-:}"
    
    # タスク詳細を検索
    local in_detail=false
    local details=()
    
    while IFS= read -r line; do
        # 詳細の開始を検出
        if [[ "$line" =~ ^-[[:space:]]*"$task_id": ]]; then
            in_detail=true
            continue
        fi
        
        # 詳細内の行を処理
        if [ "$in_detail" = true ]; then
            # 行の先頭にスペースがなければ詳細セクションの終了
            if [[ ! "$line" =~ ^[[:space:]] ]] && [[ -n "$line" ]]; then
                in_detail=false
                break
            fi
            
            # フィールド行を処理
            if [[ "$line" =~ ^[[:space:]]+([^${DETAIL_SEPARATOR}]+)${DETAIL_SEPARATOR}(.+) ]]; then
                local field="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                
                # 空でない値のみを配列に追加
                if [ -n "$value" ] && [ "$value" != "未定" ]; then
                    details+=("$field: $value")
                fi
            fi
        fi
    done < "$TASK_FILE"
    
    # 詳細を表示
    if [ ${#details[@]} -gt 0 ]; then
        local detail_indent="${indent}   "
        local last_index=$((${#details[@]} - 1))
        
        for i in "${!details[@]}"; do
            local prefix="├─"
            if [ $i -eq $last_index ]; then
                prefix="└─"
            fi
            echo "${detail_indent}${prefix} ${details[$i]}"
        done
    fi
}

# バッチ操作の実行
cmd_batch() {
    if [ $# -lt 1 ]; then
        error_exit "使用法: $0 batch <ファイル>"
    fi
    
    local input_file="$1"
    
    if ! file_exists "$input_file"; then
        error_exit "入力ファイル '$input_file' が見つかりません"
    fi
    
    # テンプレート設定を読み込む
    load_template "$CURRENT_TEMPLATE"
    
    # ファイルが存在しない場合は自動初期化
    if ! file_exists "$TASK_FILE"; then
        initialize_task_file
    fi
    
    local count=0
    while read -r line; do
        count=$((count + 1))
        
        # 空行とコメント行をスキップ
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        # 操作タイプを取得
        local op_type="${line:0:1}"
        local content="${line:1}"
        content=$(echo "$content" | sed 's/^[[:space:]]*//')
        
        case "$op_type" in
            "+")
                local parent=$(echo "$content" | grep -o '\[.*\]' | sed 's/\[\(.*\)\]/\1/')
                local rest=$(echo "$content" | sed 's/\[.*\] *//')
                IFS='|' read -r name status details design <<< "$rest"
                
                name=$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                status=$(echo "$status" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                details=$(echo "$details" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                design=$(echo "$design" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                cmd_add "$name" "$status" "$details" "$design" "$parent" || echo "警告: ${count}行目のタスク追加に失敗しました"
                ;;
            "-")
                local id=$(echo "$content" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                cmd_delete "$id" || echo "警告: ${count}行目のタスク削除に失敗しました"
                ;;
            "=")
                local id=$(echo "$content" | sed 's/^[[:space:]]*|.*//')
                id=$(echo "$id" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local status=$(echo "$content" | sed 's/^[^|]*|//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                cmd_update "$id" "$status" || echo "警告: ${count}行目の状態更新に失敗しました"
                ;;
            "*")
                IFS='|' read -r id field value <<< "$content"
                
                id=$(echo "$id" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                field=$(echo "$field" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                cmd_update_detail "$id" "$field" "$value" || echo "警告: ${count}行目の詳細更新に失敗しました"
                ;;
            *)
                echo "警告: ${count}行目: 不明な操作タイプ '$op_type'"
                continue
                ;;
        esac
    done < "$input_file"
    
    echo "バッチ操作が完了しました"
    return 0
} 