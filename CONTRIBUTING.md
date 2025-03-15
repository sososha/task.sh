# コントリビューションガイド

Task Managementプロジェクトへのコントリビューションに興味をお持ちいただき、ありがとうございます。このドキュメントでは、プロジェクトへの貢献方法について説明します。

## 開発環境のセットアップ

1. リポジトリをクローンします:
   ```bash
   git clone https://github.com/yourusername/task-management.git
   cd task-management
   ```

2. `install.sh`を使用してローカル開発環境をセットアップします:
   ```bash
   ./install.sh -l
   ```

## コーディング規約

- Bashスクリプトは[Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)に従ってください
- 関数には常にコメントで説明を付けてください
- 実装する前に必ずテストを行ってください

## プルリクエストのプロセス

1. 新しいブランチを作成します:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. 変更を加えます

3. 変更をコミットします:
   ```bash
   git commit -m "Add feature X"
   ```

4. GitHubにプッシュします:
   ```bash
   git push origin feature/your-feature-name
   ```

5. プルリクエストを作成します

## バグ報告

バグを報告する場合は、以下の情報を含めてください:

- 使用しているOSのバージョン
- 発生している問題の詳細な説明
- 問題を再現するための手順
- 期待される動作と実際の動作

## 機能リクエスト

新機能のリクエストは、GitHubのIssuesに投稿してください。以下の情報を含めると役立ちます:

- この機能がどのような問題を解決するか
- 考えられる実装方法や設計
- 関連する既存の機能

## コミュニケーション

質問や議論は、GitHubのIssuesで行ってください。 