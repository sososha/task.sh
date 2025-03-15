#!/bin/bash
# task - タスク管理コマンド
# 厳格モードを有効化
set -euo pipefail

# グローバル変数
DIR="tasks"
FILE="$DIR/tasks"
VERSION="1.0.0"
DEBUG=false

# エラーメッセージを表示して終了する関数
error_exit() {
    echo "エラー: $1" >&2
    exit 1
}

# デバッグログを出力する関数
debug_log() {
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: $1" >&2
    fi
}

# ファイルの存在チェック
check_file() {
    if [ ! -f "$FILE" ]; then
        error_exit "タスクファイルが見つかりません。'task init'で初期化してください。"
    fi
}

# ヘルプドキュメント表示関数
show_help() {
    cat << EOF
タスク管理ツール v${VERSION} - 使用方法：

task init                                 # タスクファイルを初期化
task add <親タスク> <タスク名> <状態>      # タスクを追加
                [内容] [設計思想]          # 内容と設計思想はオプション
task update <親タスク> <タスク名> <状態>   # タスク状態を更新
task update-detail <ID> <フィールド> <値>  # タスク詳細を更新
task delete <ID>                          # タスクを削除
task list [ID] [--status <状態>]          # タスク一覧表示
task help                                 # このヘルプを表示

状態: 完了, 進行中, 未着手
フィールド: 内容, 設計思想, 懸念, 実装結果, 結果的懸念

オプション:
  -v, --verbose                           # 詳細なログを出力
EOF
}

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
    local input="$3"
    
    if [ "$(detect_os)" == "macos" ]; then
        sed -i '' "$pattern" "$file"
    else
        sed -i "$pattern" "$file"
    fi
}

# タスクファイルの初期化
init() {
    if [ -f "$FILE" ]; then
        read -p "タスクファイルが既に存在します。上書きしますか？(y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "初期化をキャンセルしました。"
            exit 0
        fi
    fi

    mkdir -p $DIR
    cat > $FILE <<EOF
□ PA01 新Webアプリ開発

# Details
PA01: 新しい顧客向けWebアプリをリリース : 未定 : スケジュール遅延リスク :  : 
EOF
    echo "初期化完了"
}

# インデントを取得
get_indent() {
    local parent="$1"
    if [ -z "$parent" ]; then
        echo ""
    else
        local depth=$(grep -B1 "$parent" $FILE | grep -o '   ' | wc -l)
        printf '   %.0s' $(seq 1 "$depth")
    fi
}

# IDを生成する
get_id() {
    local parent="$1"
    local name="$2"
    if [ -z "$parent" ]; then
        echo "PA01"
    else
        local parent_id=$(grep "$parent" $FILE | grep -o '[A-Z][A-D][0-9]\{2\}' | head -n1)
        local prefix=${parent_id:0:1}
        local depth=$(grep -B1 "$parent" $FILE | grep -o '   ' | wc -l)
        local level
        case "$depth" in
            0) level="A" ;;
            1) level="B" ;;
            2) level="C" ;;
            3) level="D" ;;
            *) 
                level="D"  # 4層以上は全てDレベルとして扱う
                echo "警告: 4層以上のネストは非推奨です。管理が複雑になる可能性があります。" >&2
                ;;
        esac
        
        # 同じレベルの最大番号を取得して+1する（連番方式）
        local max_num=$(grep -o "$prefix$level[0-9]\{2\}" $FILE | sed "s/$prefix$level//" | sort -n | tail -n 1)
        if [ -z "$max_num" ]; then
            max_num=0
        fi
        local next_num=$((max_num + 1))
        local num=$(printf "%02d" $next_num)
        
        echo "$prefix$level$num"
    fi
}

# 進捗記号を取得
status_symbol() {
    case "$1" in
        "完了") echo "☑" ;;
        "進行中") echo "▣" ;;
        "未着手") echo "□" ;;
        *) 
            echo "警告: 不明な状態「$1」です。「未着手」として扱います。" >&2
            echo "□" 
            ;;
    esac
}

# タスク名の検証と正規化
normalize_name() {
    # スペースはそのまま許可、ただし検索時は注意が必要
    echo "$1" | tr -d '\n'  # 改行文字は削除
}

# タスクを追加
add_task() {
    # 入力チェック
    [ -z "${3:-}" ] && error_exit "タスク名と状態を指定してください"
    
    local parent="$1"
    local name=$(normalize_name "$2")
    local status="$3"
    local content="${4:-$name の実装}"
    local design="${5:-未定}"
    
    check_file
    
    local indent=$(get_indent "$parent")
    local id=$(get_id "$parent" "$name")
    local symbol=$(status_symbol "$status")
    
    debug_log "親タスク: '$parent', 名前: '$name', 状態: '$status', ID: '$id'"
    
    if [ -z "$parent" ]; then
        echo "$indent$symbol $id $name" >> $FILE
        echo "" >> $FILE
        echo "$id: $content : $design :  :  : " >> $FILE
    else
        # 親タスクが存在するか確認
        if ! grep -q "$parent" $FILE; then
            error_exit "親タスク '$parent' が見つかりません"
        fi
        
        # 親タスクの後にタスクを追加
        local temp_file="${FILE}.temp"
        awk -v parent="$parent" -v indent="$indent" -v symbol="$symbol" -v id="$id" -v name="$name" '
        $0 ~ parent {
            print $0
            print indent"   "symbol" "id" "name
            next
        }
        { print }
        ' "$FILE" > "$temp_file" && mv "$temp_file" "$FILE"
        
        # 詳細を追加
        local detail_line="$id: $content : $design :  :  : "
        awk -v marker="# Details" -v detail="$detail_line" '
        $0 ~ marker {
            print $0
            print detail
            next
        }
        { print }
        ' "$FILE" > "$temp_file" && mv "$temp_file" "$FILE"
    fi
    
    echo "タスク '$name' (ID: $id) を追加しました"
}

# タスクの状態を更新
update_task() {
    # 入力チェック
    [ -z "${3:-}" ] && error_exit "親タスク、タスク名、状態を指定してください"
    
    local parent="$1"
    local name="$2"
    local status="$3"
    
    check_file
    
    local symbol=$(status_symbol "$status")
    
    debug_log "更新: 親タスク: '$parent', 名前: '$name', 新状態: '$status'"
    
    # タスク行を更新
    local temp_file="${FILE}.temp"
    if ! awk -v name="$name" -v symbol="$symbol" '
    $0 ~ name {
        sub(/[☑▣□]/, symbol)
        print
        next
    }
    { print }
    ' "$FILE" > "$temp_file"; then
        error_exit "タスク '$name' が見つからないか、更新できません"
    fi
    
    mv "$temp_file" "$FILE"
    echo "タスク '$name' の状態を '$status' に更新しました"
}

# タスク詳細を更新
update_detail() {
    # 入力チェック
    [ -z "${3:-}" ] && error_exit "ID、フィールド、値を指定してください"
    
    local id="$1"
    local field="$2"
    local value="$3"
    
    check_file
    
    # フィールドの位置を確認
    local field_pos
    case "$field" in
        "内容") field_pos=1 ;;
        "設計思想") field_pos=2 ;;
        "懸念") field_pos=3 ;;
        "実装結果") field_pos=4 ;;
        "結果的懸念") field_pos=5 ;;
        *) error_exit "不正なフィールド名: $field\n有効なフィールド: 内容, 設計思想, 懸念, 実装結果, 結果的懸念" ;;
    esac
    
    debug_log "詳細更新: ID: '$id', フィールド: '$field', 値: '$value'"
    
    # IDの存在確認
    if ! grep -q "$id: " $FILE; then
        error_exit "ID '$id' が見つかりません"
    fi
    
    # 一時ファイルにawk処理の結果を出力
    local temp_file="${FILE}.temp"
    awk -v id="$id" -v pos="$field_pos" -v val="$value" '
    $0 ~ "^"id": " {
        split($0, parts, " : ")
        parts[pos] = val
        $0 = id": "
        for (i=1; i<=5; i++) {
            $0 = $0 parts[i] (i<5 ? " : " : "")
        }
    }
    { print }
    ' $FILE > "$temp_file"
    
    # 更新が成功したか確認
    if [ $? -eq 0 ]; then
        mv "$temp_file" "$FILE"
        echo "ID '$id' の $field を '$value' に更新しました"
    else
        rm -f "$temp_file"
        error_exit "詳細の更新に失敗しました"
    fi
}

# タスクを削除
delete_task() {
    # 入力チェック
    [ -z "${1:-}" ] && error_exit "削除するタスクのIDを指定してください"
    
    local id="$1"
    
    check_file
    
    debug_log "削除: ID: '$id'"
    
    # IDの存在確認
    if ! grep -q "$id" $FILE; then
        error_exit "ID '$id' が見つかりません"
    fi
    
    # タスク行と詳細行を削除
    local temp_file="${FILE}.temp"
    awk -v id="$id" '
    !($0 ~ "[☑▣□] "id" " || $0 ~ "^"id": ") { print }
    ' "$FILE" > "$temp_file" && mv "$temp_file" "$FILE"
    
    echo "ID '$id' のタスクを削除しました"
}

# タスク一覧を表示
list_tasks() {
    local id="${1:-}"
    local status_flag="${2:-}"
    local status_value="${3:-}"
    
    check_file
    
    if [ -n "$id" ]; then
        # 特定IDのタスクを表示
        debug_log "表示: 特定ID '$id'"
        grep -A100 "[☑▣□] $id " $FILE | grep -B100 "# Details" | sed '/# Details/d'
        grep "$id: " $FILE
    elif [ "$status_flag" = "--status" ]; then
        # 特定状態のタスクのみ表示
        local symbol=$(status_symbol "$status_value")
        debug_log "表示: 状態 '$status_value' ($symbol)"
        grep "^[[:space:]]*$symbol" $FILE
    else
        # 全タスク表示
        debug_log "表示: 全タスク"
        cat $FILE
    fi
}

# コマンドライン引数の解析
parse_args() {
    # デバッグフラグを確認
    for arg in "$@"; do
        if [ "$arg" = "-v" ] || [ "$arg" = "--verbose" ]; then
            DEBUG=true
            debug_log "デバッグモード有効"
            break
        fi
    done
    
    # メインコマンドの処理
    case "${1:-}" in
        "init") init ;;
        "add") shift; add_task "$@" ;;
        "update") shift; update_task "$@" ;;
        "update-detail") shift; update_detail "$@" ;;
        "delete") shift; delete_task "$@" ;;
        "list") shift; list_tasks "$@" ;;
        "help"|"--help"|"-h") show_help ;;
        "") show_help ;;
        *) error_exit "未知のコマンド: $1\nヘルプを表示するには: task help" ;;
    esac
}

# メイン処理の実行
parse_args "$@" 