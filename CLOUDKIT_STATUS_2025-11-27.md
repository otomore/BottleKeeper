# CloudKit同期問題 - 現状レポート (2025-11-27)

## 本日の作業サマリー

### 試したこと
1. CloudKit環境をProduction専用に変更（趣味開発のためシンプル化）
2. Development証明書・プロビジョニングプロファイルを作成
3. GitHub ActionsでDevelopment IPAをビルド
4. 実機（TestFlight）でProduction環境に接続してスキーマ初期化を試行

### 結果
Production環境では`initializeCloudKitSchema`が**スキーマを新規作成できない**ことが判明。
エラー内容：
```json
{
  "overallStatus": "USER_ERROR",
  "error": "OTHER",
  "returnedRecordTypes": "_pcs_data"
}
```

---

## 問題の根本原因

### `_pcs_data`とは
- NSPersistentCloudKitContainerが内部で使用するシステムレコードタイプ
- iCloudアカウントのセキュリティ・暗号化に関連
- **手動でCloudKit Dashboardから作成することは不可能**
- `initializeCloudKitSchema`を実行した時に**自動生成される**

### なぜ問題が発生したか
1. 旧コンテナ（`iCloud.com.bottlekeep.whiskey`）から新コンテナ（`v2`）にスキーマを**手動エクスポート/インポート**した
2. 手動インポートでは`_pcs_data`は含まれない
3. Production環境では`initializeCloudKitSchema`が動作しない（スキーマ変更不可）
4. Development環境で実機を使ってスキーマを初期化する必要がある

### Appleの設計意図
- Development環境：スキーマの作成・変更が可能（開発中）
- Production環境：スキーマの作成・変更は不可（リリース後の安定性のため）
- TestFlightは常にProduction環境を強制

---

## 現在の環境状態

### CloudKitコンテナ: `iCloud.com.bottlekeep.whiskey.v2`

| 環境 | スキーマ状況 | `_pcs_data` |
|------|-------------|-------------|
| Development | 空（何もなし） | ❌ なし |
| Production | CD_Bottle, CD_BottlePhoto, CD_DrinkingLog, CD_WishlistItem, Users | ❌ なし |

### 証明書・プロファイル
- Distribution証明書: ✅ 作成済み（2026/09/27まで有効）
- Development証明書: ✅ 作成済み（2026/11/27まで有効）
- Distribution Profile: ✅ 作成済み
- Development Profile: ✅ 作成済み

### GitHub Secrets
- `BUILD_CERTIFICATE_BASE64`: Distribution証明書
- `DEV_CERTIFICATE_P12_BASE64`: Development証明書
- `DEV_PROVISIONING_PROFILE_BASE64`: Development Profile

---

## 選択肢と推奨

### 選択肢1: 実機でDevelopment IPAを使ってスキーマ初期化（推奨度: ★★★★☆）

**手順:**
1. Sideloadly等で`dev-ipa/BottleKeeper.ipa`を実機にインストール
2. アプリを起動（iCloudにログイン済みの状態）
3. `initializeCloudKitSchema`がDevelopment環境でスキーマを自動作成
4. CloudKit DashboardでDevelopment → Productionにスキーマをデプロイ
5. EntitlementsをProductionに変更してTestFlightリリース

**メリット:**
- 現在の進捗を活かせる
- 正しいフローでスキーマが作成される

**デメリット:**
- Sideloadly等のサードパーティツールが必要
- 実機操作が必要

---

### 選択肢2: 新しいCloudKitコンテナで最初からやり直し（推奨度: ★★★★★）

**手順:**
1. 新しいコンテナ`iCloud.com.bottlekeep.whiskey.v3`を作成
2. **手動インポートせず**、最初から実機でスキーマを初期化
3. 以降は正しいフローで進める

**メリット:**
- クリーンな状態からスタート
- 過去の設定ミスの影響を受けない
- `_pcs_data`が最初から正しく作成される

**デメリット:**
- これまでの作業（v2コンテナ）が無駄になる
- 再度プロビジョニングプロファイルの更新が必要

---

### 選択肢3: CloudKit同期を一旦無効化してリリース（推奨度: ★★★☆☆）

**手順:**
1. CloudKit同期コードを無効化（ローカルCore Dataのみ）
2. TestFlightでリリース
3. 後日、環境が整ったらCloudKit同期を追加

**メリット:**
- すぐにアプリをリリースできる
- CloudKit問題を後回しにできる

**デメリット:**
- iCloud同期機能が使えない
- 後で再実装が必要

---

### 選択肢4: 一から開発し直し（推奨度: ★★★★☆）

**検討事項:**
- 現在のコードベースに問題があるわけではない
- CloudKitの設定・スキーマ管理の問題
- 新プロジェクトを作っても同じ問題に直面する可能性

**この選択肢が有効なケース:**
- Xcodeの新しいテンプレートでCloudKit対応プロジェクトを作成
- 最初からDevelopment環境でスキーマを初期化
- 過去の設定を引きずらない

---

## 私の見解

### 根本的な問題
「Macなし環境でのiOS開発」という制約が、CloudKitの初期設定を困難にしている。

### 推奨アプローチ
**選択肢2（新しいコンテナで最初からやり直し）** を推奨。

理由:
1. v2コンテナはProductionにスキーマがデプロイ済みで、修正が困難
2. 新しいコンテナなら、最初から正しいフローでセットアップ可能
3. 手動インポートの罠を回避できる

### 一から開発し直す必要性について
**コードの問題ではない**ので、一から開発し直す必要はないと考えます。

問題は以下の手順ミス:
1. ❌ スキーマを手動インポートした
2. ❌ Production環境で直接スキーマ初期化を試みた

正しい手順:
1. ✅ Development環境で実機を使ってスキーマを初期化
2. ✅ CloudKit DashboardでProduction環境にデプロイ
3. ✅ EntitlementsをProductionに変更してリリース

---

## 明日の作業に向けて

### 必要な準備
1. **Sideloadly**をインストール（https://sideloadly.io/）
   - WindowsでIPAを実機にインストールするツール
   - Apple IDでサインインが必要

2. **実機（iPhone 6 Plus）**を用意
   - iCloudにログイン済みの状態で

### 作業手順（選択肢2を選ぶ場合）
1. Apple Developer Portalで新しいCloudKitコンテナを作成
2. App IDに新しいコンテナを関連付け
3. プロビジョニングプロファイルを再生成
4. コード内のコンテナIDを更新
5. Development IPAをビルド
6. Sideloadlyで実機にインストール
7. アプリを起動してスキーマを初期化
8. CloudKit DashboardでDevelopment → Productionにデプロイ
9. EntitlementsをProductionに変更
10. TestFlightでリリース

---

## 参考リンク

- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
- [Apple Developer Portal - CloudKit Containers](https://developer.apple.com/account/resources/identifiers/list/cloudContainer)
- [Sideloadly](https://sideloadly.io/)
- [Stack Overflow: initializeCloudKitSchema](https://stackoverflow.com/questions/68544092/when-to-use-nspersistentcloudkitcontainer-initializecloudkitschema)

---

## 関連ファイル

- `BottleKeeper/BottleKeeper.entitlements` - CloudKitコンテナID設定
- `BottleKeeper/Services/CoreDataManager.swift` - CloudKit同期ロジック
- `.github/workflows/development-build.yml` - Development IPAビルド
- `dev-ipa/BottleKeeper.ipa` - 最新のDevelopment IPA（Development環境接続）

---

*作成日: 2025-11-27 03:10 JST*
