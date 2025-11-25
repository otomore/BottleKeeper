# Claude Code 設定

このプロジェクトでは、Claude Codeとのすべてのやり取りを日本語で行います。

## 言語設定

- **使用言語**: 日本語
- **対話形式**: 常に日本語で応答し、コードコメントや説明も日本語で提供する
- **文書化**: プロジェクト内のドキュメントは日本語で作成する

## 指示

Claude Code は以下のルールに従ってください：

1. すべての応答を日本語で行う
2. コードのコメントを日本語で記述する
3. エラーメッセージの説明を日本語で提供する
4. ファイル名や変数名の説明を日本語で行う
5. 技術的な説明や提案も日本語で提供する

## Git操作のルール

このリポジトリでは以下のGit操作ルールを厳守する：

1. **`git add -A` コマンドの使用を禁止**
2. **`git add .` コマンドの使用を禁止**
3. 変更したファイルは必ず個別に `git add <ファイルパス>` で追加する
4. 複数のファイルを追加する場合も、それぞれ個別にaddコマンドを実行する

---

## プロジェクト固有の重要な知見

### CloudKitスキーマ管理

**絶対に守るべき原則**:
1. **手動でImport Schemaを使用しない**
   - 手動インポートでは`_pcs_data`システムレコードタイプが作成されない
   - NSPersistentCloudKitContainerの自動生成のみを使用すること

2. **スキーマ初期化のタイミング**
   - `initializeCloudKitSchema()`は`loadPersistentStores`完了後に実行
   - DEBUGビルドで一度だけ実行（UserDefaultsでフラグ管理）
   - RELEASEビルドでは実行しない（既にスキーマが存在すべき）

3. **既存スキーマの問題**
   - Production環境のスキーマは削除不可
   - 既存スキーマに`_pcs_data`を後から追加することは不可能
   - 問題が発生したら新しいCloudKitコンテナを作成するのが確実

### 開発環境

**Macなし環境での開発フロー**:
- GitHub Actionsをビルド＆テスト環境として活用
- シミュレーター起動とスキーマ初期化もGitHub Actionsで実行
- プロビジョニングプロファイルはApple Developer Portal（Web）で管理
- すべての設定変更はファイル編集で実施（Xcode GUI不要）

### Playwrightブラウザ常時表示ルール

**開発作業開始時は、以下のページをPlaywrightブラウザで開いておくこと**:

1. **CloudKit Dashboard** (Development環境)
   - URL: https://icloud.developer.apple.com/dashboard/
   - Container: `iCloud.com.bottlekeep.whiskey.v2`
   - Environment: `Development` → `Production`（段階に応じて切り替え）
   - 用途: スキーマ確認、レコードタイプ確認、ログ確認

2. **Apple Developer Portal - CloudKit Containers**
   - URL: https://developer.apple.com/account/resources/identifiers/list/cloudContainer
   - 用途: CloudKitコンテナ管理、新規作成

3. **Apple Developer Portal - Provisioning Profiles**
   - URL: https://developer.apple.com/account/resources/profiles/list
   - 用途: プロビジョニングプロファイル管理、更新、ダウンロード

4. **GitHub Actions**
   - URL: https://github.com/otomore/BottleKeeper/actions
   - 用途: ビルド状況確認、ログ確認、手動実行

5. **App Store Connect**
   - URL: https://appstoreconnect.apple.com/
   - 用途: TestFlightビルド確認、配信状況確認

**理由**: これらのページを常時開いておくことで、作業効率が大幅に向上し、状況確認がリアルタイムで可能になる。

### CloudKit関連の重要ファイル

**変更時は必ずセットで更新**:
1. `BottleKeeper/BottleKeeper.entitlements` - CloudKitコンテナID
2. `BottleKeeper/Services/CoreDataManager.swift` - containerIdentifier定数
3. プロビジョニングプロファイル - 新しいコンテナを含める必要あり

**参考ドキュメント**:
- `CLOUDKIT_SYNC_STATUS.md` - 問題の詳細な履歴
- `CLOUDKIT_MIGRATION_NO_MAC.md` - Macなし環境での移行手順

### 現在のCloudKitコンテナ

- **Container ID**: `iCloud.com.bottlekeep.whiskey.v2`
- **Team ID**: `B3QHWZX47Z`
- **環境**: Development（初期スキーマ生成中）→ Production（デプロイ予定）

---

この設定により、このプロジェクトにおけるClaude Codeとのやり取りは継続的に日本語で行われます。