#!/bin/bash
# format_tasks.sh - タスク詳細のフォーマットを修正するスクリプト

# 現在のスクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# グローバル変数
TASKS_DIR="${SCRIPT_DIR}/tasks"
TASK_FILE="${TASKS_DIR}/tasks"
TEMPLATES_DIR="${TASKS_DIR}/templates"
CURRENT_TEMPLATE="${TEMPLATES_DIR}/current_template.yaml"
DEBUG=true

# ライブラリモジュールの読み込み
source "${SCRIPT_DIR}/lib/core/file_utils.sh"
source "${SCRIPT_DIR}/lib/core/task_processor.sh"
source "${SCRIPT_DIR}/lib/template/template_manager.sh"

# テンプレート設定を読み込む
load_template "$CURRENT_TEMPLATE"

# タスク詳細をフォーマット
format_task_details "$TASK_FILE"

echo "タスク詳細のフォーマットが完了しました"
exit 0
