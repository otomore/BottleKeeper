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

## 実行時の厳守事項

- **影響範囲の確認**: 変更を行う前に、意図しない副作用が発生する可能性のある箇所を特定し、影響範囲を明確にしてから作業を実施すること。

- **曖昧な表現の禁止**: 「〜の可能性があります」「〜かもしれません」などの曖昧な表現を使用しない。必ず一次情報（公式ドキュメント、ソースコード等）を根拠とし、根拠となるURLと該当箇所の引用をユーザーに提示すること。

- **独断でのUI変更の禁止**: ユーザーから明示的な指示がない限り、UIのデザインやスタイリングを独自に変更・追加しないこと。

- **エラーの隠蔽の禁止**: 失敗しているテストをskipしたり、削除したり、エラーメッセージを握りつぶすなど、問題を隠蔽する行為を行わないこと。

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
- プロビジョニングプロファイルはApple Developer Portal（Web）で管理
- すべての設定変更はファイル編集で実施（Xcode GUI不要）

**CloudKitスキーマ初期化**:
- スキーマ初期化は**一度だけ**必要（Development環境セットアップ時）
- `development-build.yml`ワークフローを手動実行してDevelopment IPAをビルド
- ビルドしたIPAをテスト端末にインストールしてアプリを起動するとスキーマが生成される

### Playwrightブラウザ常時表示ルール

**開発作業開始時は、以下のページをPlaywrightブラウザで開いておくこと**:

1. **CloudKit Dashboard** (Development環境)
   - URL: https://icloud.developer.apple.com/dashboard/
   - Container: `iCloud.com.bottlekeep.whiskey.v3`
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

- **Container ID**: `iCloud.com.bottlekeep.whiskey.v3`
- **Team ID**: `B3QHWZX47Z`
- **環境**: Development（初期スキーマ生成中）→ Production（デプロイ予定）

### TestFlight自動配信の設定

**コンプライアンス設定の自動化**:
- `Info.plist`に`ITSAppUsesNonExemptEncryption`キーを`false`に設定済み
- HTTPSのみを使用するアプリは暗号化免除対象のため、`false`が適切
- 参考: https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption

**Fastlaneによるアップロード**:
- `fastlane/Fastfile`の`upload_to_testflight`で以下のパラメータを設定:
  - `skip_waiting_for_build_processing: false` - ビルド処理完了を待つ
  - `skip_submission: true` - アップロードのみ（配信はApp Store Connect側で管理）

**重要な注意点**:
- `groups`パラメータは**外部テスター**用であり、**内部テスターには適用不可**
- 内部テスターへの自動配信はApp Store Connectで「自動配信」を有効にすることで実現
- App Store Connect → アプリ → TestFlight → 内部テスト → グループ設定 → 「自動配信」をON

---

この設定により、このプロジェクトにおけるClaude Codeとのやり取りは継続的に日本語で行われます。