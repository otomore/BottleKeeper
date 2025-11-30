import Foundation

/// UserDefaultsのキー定義
///
/// アプリ全体で使用するUserDefaultsキーを一元管理。
/// タイポを防ぎ、キーの変更時の影響範囲を最小化します。
enum UserDefaultsKeys {
    // MARK: - Notification Settings

    /// 通知機能の有効/無効
    static let notificationsEnabled = "notificationsEnabled"

    /// 残量少なし通知の閾値（パーセンテージ）
    static let lowStockThreshold = "lowStockThreshold"

    /// 30日後通知の有効/無効
    static let notifyAt30Days = "notifyAt30Days"

    /// 60日後通知の有効/無効
    static let notifyAt60Days = "notifyAt60Days"

    /// 90日後通知の有効/無効
    static let notifyAt90Days = "notifyAt90Days"

    // MARK: - CloudKit Settings

    /// CloudKitコンテナID（コンテナ変更検出用）
    static let cloudKitContainerID = "cloudKitContainerID"

    /// CloudKitスキーマ初期化済みフラグ（v4コンテナ用）
    /// 注: v3からv4への移行時にキー名を変更し、新しいコンテナのスキーマ初期化を強制
    static let cloudKitSchemaInitialized = "cloudKitSchemaInitialized_v4"

    /// CloudKitスキーマ初期化日時（v4コンテナ用）
    static let cloudKitSchemaInitializedDate = "cloudKitSchemaInitializedDate_v4"
}
