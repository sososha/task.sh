# Task Management

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-blue.svg)](https://github.com/yourusername/task-management)

軽量でシンプルなタスク管理ツール。シェルスクリプトで動作し、視覚的に分かりやすいMarkdown風のデータ形式を採用しています。依存関係なしで、どのUNIX互換環境でも動作します。

![スクリーンショット](docs/screenshot.png)

## 目次

- [特徴](#特徴)
- [必要条件](#必要条件)
- [インストール方法](#インストール方法)
- [使用方法](#使用方法)
- [設定](#設定)
- [データ形式](#データ形式)
- [コントリビューション](#コントリビューション)
- [ライセンス](#ライセンス)

## 特徴

- **シンプルさ**: 外部依存なし、純粋なシェルスクリプトで実装
- **視覚的**: 進捗記号（☑ ▣ □）とインデントで階層構造を表現
- **コンパクト**: タスク一覧と詳細情報を分離してファイルサイズを抑制
- **ID体系**: 階層と連番を組み合わせた4文字IDで一意のタスク管理
- **ポータブル**: どのディレクトリでも初期化して使用可能
- **カスタマイズ可能**: シンプルな構造で拡張が容易
- **自動フォーマット**: タスク詳細の自動整形で読みやすいフォーマットを維持

## 必要条件

- Bashシェル (バージョン4.0以上推奨)
- 基本的なUNIXコマンド: `grep`, `awk`, `sed`など

## インストール方法

### 方法1: インストールスクリプトを使用（推奨）

```bash
# リポジトリをクローン
git clone https://github.com/yourusername/task-management.git
cd task-management

# インストールスクリプトを実行
./install.sh

# PATHに追加する必要がある場合は指示に従ってください
```

インストールオプション:
- `-b, --bin-dir <dir>`: 実行ファイルのインストール先を指定（デフォルト: `$HOME/bin`）
- `-d, --dir <dir>`: スクリプト一式のインストール先を指定（デフォルト: `$HOME/.task-management`）
- `-l, --local`: 開発用にカレントディレクトリにシンボリックリンクを作成

### 方法2: 手動インストール

```bash
# リポジトリをクローン
git clone https://github.com/yourusername/task-management.git
cd task-management

# スクリプトを実行可能にする
chmod +x task.sh

# 任意のPATHの通ったディレクトリにシンボリックリンクを作成
ln -s "$(pwd)/task.sh" ~/bin/task

# PATHに~/binディレクトリが含まれていることを確認
echo 'export PATH="$PATH:$HOME/bin"' >> ~/.bashrc  # または ~/.zshrc など
source ~/.bashrc  # または ~/.zshrc
```

## 使用方法

### 初期化

```bash
# タスクファイルを初期化
task init
```

### タスクの追加

```bash
# 最上位タスクを追加
task add "" "新規プロジェクト" "未着手" "大規模プロジェクトの立ち上げ" "アジャイル手法を採用"

# 子タスクを追加（親タスク名を指定）
task add "新規プロジェクト" "要件定義" "進行中"

# 孫タスクを追加（親タスク名を指定）
task add "要件定義" "ユーザーストーリー作成" "進行中"
```

### タスク状態の更新

```bash
# タスクのステータスを更新
task update "新規プロジェクト" "要件定義" "完了"
```

### タスク詳細の更新

```bash
# タスク詳細を更新（IDでタスクを指定）
task update-detail "RB01" "懸念" "スケジュールの遅延リスク"
```

### タスクの削除

```bash
# タスクを削除（IDでタスクを指定）
task delete "RC03"
```

### タスク一覧の表示

```bash
# 全タスク表示
task list

# 特定IDのタスクのみ表示
task list "PA01"

# 特定状態のタスクのみ表示
task list --status "完了"
```

### タスク詳細のフォーマット

```bash
# タスク詳細のフォーマットを整理
task format
```

### デバッグモード

```bash
# デバッグログを表示して実行
task -v list
```

## 設定

現在、設定ファイルはサポートされていませんが、将来のバージョンで追加される予定です。

## データ形式

タスク管理データは `tasks/tasks` ファイルに保存されます。フォーマットは以下の通りです：

```
☑ PA01 完了したタスク
   ▣ RB01 進行中のタスク
      □ RC01 未着手のタスク

# Details
PA01: タスクの内容 : 設計思想 : 懸念点 : 実装結果 : 結果的懸念
RB01: タスクの内容 : 設計思想 : 懸念点 : 実装結果 : 結果的懸念
RC01: タスクの内容 : 設計思想 : 懸念点 : 実装結果 : 結果的懸念
```

### ID体系

- **1文字目**: 親タスクの頭文字（例: `P`=Project, `R`=Realization）
- **2文字目**: ネスト深さ（`A`=1層, `B`=2層, `C`=3層, `D`=4層）
- **3～4文字目**: 連番（`01`～`99`、同一レベルで自動採番）

## コントリビューション

コントリビューションは大歓迎です！詳細は[CONTRIBUTING.md](CONTRIBUTING.md)を参照してください。

## ライセンス

このプロジェクトは[MIT License](LICENSE)の下で公開されています。 