# BottleKeeper 総合解決プラン

**作成日**: 2025-11-26
**ステータス**: 実装完了・検証待ち
**対象課題**:
1. CFBundleVersion自動更新
2. iCloud同期問題（`_pcs_data`欠落）

---

## 1. CFBundleVersion自動更新 ✅ 実装完了

### 実装内容

`.github/workflows/ios-build.yml` (line 203-222)に以下の機能を追加：

```yaml
- name: ビルド番号を自動更新
  run: |
    BUILD_NUMBER=$GITHUB_RUN_NUMBER

    # PlistBuddyでInfo.plistのCFBundleVersionを更新
    INFO_PLIST_PATH="BottleKeeper/Info.plist"

    # 現在のバージョンを表示
    CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST_PATH")
    echo "現在のCFBundleVersion: $CURRENT_VERSION"

    # 新しいバージョンに更新
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$INFO_PLIST_PATH"

    # 更新結果を確認
    NEW_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST_PATH")
    echo "✅ CFBundleVersion更新完了: $CURRENT_VERSION → $NEW_VERSION"
```

### 動作

- GitHub Actions Run番号をCFBundleVersionに自動設定
- 現在のInfo.plistの値: "2"
- 次回ビルド（Run #219）: "219"に自動更新
- 以降、手動更新不要

### 期待される効果

- ビルド番号の更新忘れを防止
- TestFlightビルドの一意性を保証
- GitHub Actionsログでバージョン変更を確認可能

---

## 2. iCloud同期問題（`_pcs_data`欠落） ⚠️ 検証必要

### 📊 現状分析（2025-11-26更新）

**CloudKitダッシュボード確認結果**:
- コンテナ: `iCloud.com.bottlekeep.whiskey.v2`
- 環境: Development
- レコードタイプ:
  - ✅ **Users**: 7フィールド（存在）
  - ❌ **CD_Bottle**: 欠落
  - ❌ **CD_BottlePhoto**: 欠落
  - ❌ **CD_DrinkingLog**: 欠落
  - ❌ **CD_WishlistItem**: 欠落
  - ❌ **`_pcs_data`**: **欠落（最重要）**

**GitHub Actions Run #19677636369の結果（2025-11-26）**:
- ✅ DEBUGビルド成功
- ✅ シミュレーターリセット成功
- ✅ アプリインストール成功
- ✅ Swiftコンパイルエラー解消（log→print修正）
- ❌ **アプリ起動ログが一切出力されず**
- ❌ **`found nothing to terminate` エラー → アプリが起動していない**
- ❌ CloudKitスキーマ初期化が実行されなかった

**診断結果（Ultrathink分析）**:
- **根本原因**: ログキャプチャ方法の問題
  - `xcrun simctl launch --console` の出力がバッファリングされ、`tee` で `simulator.log` に書き込まれない
  - バックグラウンドプロセスとして実行後、60秒でkillするため、バッファがフラッシュされる前に終了
  - 実際にアプリが起動したかどうかも不明
- **可能性のある二次的問題**:
  - GitHub Actionsシミュレーターが **iCloudにサインインしていない**
  - CloudKitはApple IDなしではDevelopment環境にアクセスできない可能性
  - DEBUGビルドで `CODE_SIGNING_REQUIRED=NO` だが、CloudKitは署名が必要な可能性

### 🧠 根本原因分析（Ultrathink）

#### 仮説1: UserDefaultsフラグの永続化（確率: 95%）

**メカニズム**:
```swift
// CoreDataManager.swift
static let cloudKitSchemaInitialized = "cloudKitSchemaInitialized"
```

このUserDefaultsキーは**コンテナIDを含んでいない**ため：
1. 旧コンテナ（iCloud.com.bottlekeep.whiskey）でスキーマ初期化済み
2. 新コンテナ（iCloud.com.bottlekeep.whiskey.v2）に切り替え
3. **同じUserDefaultsキーを参照** → 「初期化済み」と誤判断
4. `attemptSchemaInitializationIfNeeded()`が早期リターン

**既存のコンテナ変更検知ロジック**（CoreDataManager.swift line 104-115）:
```swift
#if DEBUG
let currentContainerID = UserDefaults.standard.string(forKey: "cloudKitContainerID")
let expectedContainerID = CoreDataConstants.cloudKitContainerIdentifier

if currentContainerID != expectedContainerID {
    UserDefaults.standard.removeObject(forKey: CoreDataConstants.UserDefaultsKeys.cloudKitSchemaInitialized)
    UserDefaults.standard.removeObject(forKey: CoreDataConstants.UserDefaultsKeys.cloudKitSchemaInitializedDate)
    UserDefaults.standard.set(expectedContainerID, forKey: "cloudKitContainerID")
    print("🔄 CloudKit container changed to \(expectedContainerID)")
    print("🔄 UserDefaults cleared for new schema initialization")
}
#endif
```

**問題点**:
- `print()`ではなく`log()`を使用すべき
- GitHub ActionsのシミュレーターでUserDefaultsが残っている可能性
- 最初の実行時、`currentContainerID`が`nil`の場合、条件が成立しない

#### 仮説2: GitHub Actions環境問題（確率: 40%）

- シミュレーターログキャプチャが不完全
- `xcrun simctl launch --console`の出力が標準エラーに流れている
- アプリがバックグラウンドで起動し、初期化が遅延

### 🎯 解決策

#### 解決策A: ログキャプチャ方法の改善（実装済み - 2025-11-26）

**`.github/workflows/ios-build.yml`に実装済み**:

```yaml
# 新しい診断機能
- インストール済みアプリ確認: xcrun simctl listapps
- システムログストリーミング: log stream --predicate 'process == "BottleKeeper"'
- timeout使用: フォアグラウンドで60秒実行し、バッファリング問題を回避
- スクリーンショット撮影: 起動状態を視覚的に確認
- クラッシュログ確認: ~/Library/Logs/DiagnosticReports/
- ログファイルアーティファクト: app.log, system.log, screenshot.png をアップロード
```

**期待される効果**:
- アプリが実際に起動しているか確認可能
- クラッシュした場合の詳細なエラー情報を取得
- CloudKitスキーマ初期化のログを正確にキャプチャ
- 視覚的にGUI状態を確認

**次回Run（#221以降）で検証予定**

#### 解決策B: GitHub Actionsでシミュレーターリセット（実装済み）

**`.github/workflows/ios-build.yml`に実装済み**:

```yaml
# シミュレーター起動前
- name: シミュレーターをリセット
  run: |
    echo "🔄 シミュレーターデータをリセット中..."
    SIMULATOR_ID=$(xcrun simctl list devices available | grep "iPhone 16 Pro" | head -n 1 | grep -o "[0-9A-F-]\{36\}")
    xcrun simctl erase "$SIMULATOR_ID"
    echo "✅ シミュレーターリセット完了"
```

**メリット**:
- UserDefaultsを含むすべてのシミュレーターデータをクリア
- 確実にクリーンな環境でスキーマ初期化を実行
- コード変更不要

**ステータス**: ✅ 実装完了

#### 解決策C: print()でコンテナ変更を検知（実装済み）

**CoreDataManager.swift line 112-113を修正済み**:

```swift
// init()内では log() の代わりに print() を使用（Swift初期化順序制約のため）
print("🔄 CloudKit container changed from \(currentContainerID ?? "nil") to \(expectedContainerID)")
print("🔄 UserDefaults cleared for new schema initialization")
```

**理由**:
- `log()` は `self.logger` にアクセスするため、`self` が完全初期化される前に使用不可
- `print()` はグローバル関数なので初期化中でも使用可能
- GitHub Actions Run #19677523106のSwiftコンパイルエラーを解消

**ステータス**: ✅ 実装完了

#### 解決策D: プロビジョニングプロファイル更新（未実施・必須）

**現在の問題** (GitHub Actions Run #18432219295で確認):
```
Provisioning profile "BottleKeep Distribution" doesn't match the entitlements
file's value for the com.apple.developer.icloud-container-identifiers entitlement.
```

**手順**:
1. Apple Developer Portal → Profiles → "BottleKeeper Distribution"
2. "Edit" → iCloud Services → `iCloud.com.bottlekeep.whiskey.v2` にチェック
3. "Save" → ダウンロード
4. GitHub Secrets更新:
   ```powershell
   $profile = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes("ダウンロードしたプロファイル.mobileprovision"))
   gh secret set BUILD_PROVISION_PROFILE_BASE64_NEW --body $profile
   ```

### 📋 実装チェックリスト

#### ステップ1: GitHub Actionsワークフロー修正

- [x] CFBundleVersion自動更新機能を追加（Run #220で動作確認済み）
- [x] シミュレーターリセット機能を追加（解決策B）
- [x] ログ収集方法を根本的に改善（解決策A）:
  - [x] システムログストリーミング (`log stream`)
  - [x] `timeout` でフォアグラウンド実行
  - [x] スクリーンショット撮影
  - [x] クラッシュログ確認
  - [x] ログファイルアーティファクトアップロード

#### ステップ2: コード修正

- [x] CoreDataManager.swift: `log()` → `print()` に変更（解決策C、Swift初期化順序エラー解消）

#### ステップ3: プロビジョニングプロファイル更新（未実施・必須）

- [ ] Apple Developer Portalでプロファイル更新
- [ ] 新プロファイルをダウンロード
- [ ] GitHub Secrets更新

#### ステップ4: 検証（次回Run #221以降で実施）

- [ ] GitHub Actionsで次回ビルドを実行
- [ ] 新しいログキャプチャ方法で詳細なログを確認:
  - [ ] `app.log`: アプリ起動ログを確認
  - [ ] `system.log`: システムログからCloudKit関連メッセージを確認
  - [ ] `screenshot.png`: アプリのGUI状態を視覚的に確認
  - [ ] クラッシュログ: アプリがクラッシュしていないか確認
- [ ] アプリが正常に起動しているか確認
- [ ] CloudKitログで以下を確認:
  - `🔄 CloudKit container changed from nil to iCloud.com.bottlekeep.whiskey.v2`
  - `🔄 UserDefaults cleared for new schema initialization`
  - `🔄 Attempting automatic schema initialization...`
  - `✅ CloudKit schema initialized successfully`
- [ ] CloudKitダッシュボードで`_pcs_data`の存在を確認
- [ ] ビルドジョブが成功することを確認

#### ステップ5: Production展開

- [ ] entitlementsをProductionに変更
- [ ] CloudKitスキーマをProductionにデプロイ
- [ ] TestFlightビルドを作成
- [ ] 2台のデバイスでデータ同期をテスト

---

## 3. 期待される最終状態

### GitHub Actions

- ✅ mainブランチへのpushで自動ビルド＆TestFlight配信
- ✅ CFBundleVersionがRun番号に自動更新
- ✅ DEBUGビルドでCloudKitスキーマ自動初期化
- ✅ RELEASEビルドでIPA作成＆配信
- ✅ プロビジョニングプロファイル問題解決

### CloudKit

- ✅ Development環境に完全なスキーマ（`_pcs_data`を含む）
- ✅ Production環境にデプロイ済み
- ✅ 2台以上のデバイス間でデータ同期が動作

### TestFlight

- ✅ ビルド218（または最新）がtesterグループに配信済み
- ✅ Export compliance自動設定
- ✅ 自動配信が機能

---

## 4. トラブルシューティング

### 問題: スキーマ初期化が再度失敗する

**症状**: GitHub Actions実行後もCloudKitにスキーマが作成されない

**解決策**:
1. CloudKitダッシュボード → Development環境 → "Reset Environment..."
2. GitHub Actionsを再実行
3. それでも失敗する場合、ローカルMacでXcodeシミュレーター起動を試す

### 問題: プロビジョニングプロファイルエラーが継続

**症状**: `Provisioning profile doesn't include...`エラー

**解決策**:
1. Apple Developer Portalで現在のプロファイルを削除
2. 新しいプロファイルを作成（両方のコンテナを含む）
3. GitHub Secrets `BUILD_PROVISION_PROFILE_BASE64_NEW`を更新

### 問題: TestFlightビルドでデータ同期しない

**症状**: ビルドは成功するがデータが同期されない

**解決策**:
1. entitlementsが`Production`になっているか確認
2. CloudKitダッシュボードでProduction環境にスキーマがデプロイされているか確認
3. アプリのSettingsViewでCloudKitログを確認

---

## 5. 参考ドキュメント

| ファイル | 内容 |
|---------|------|
| `CLOUDKIT_SYNC_STATUS.md` | 問題の詳細な履歴（648行） |
| `CLOUDKIT_RESOLUTION_PLAN.md` | 解決プラン（437行） |
| `CLAUDE.md` | プロジェクト設定とCloudKit知見 |
| `CoreDataManager.swift` | スキーマ初期化ロジック（559行） |
| `.github/workflows/ios-build.yml` | GitHub Actionsワークフロー（343行） |
| `fastlane/Fastfile` | TestFlight自動配信設定 |

---

**作成者**: Claude Code
**最終更新**: 2025-11-26
**次のアクション**: ステップ1のGitHub Actionsワークフロー修正を完了後、ステップ3のプロファイル更新を実施
