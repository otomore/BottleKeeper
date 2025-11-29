import Foundation

/// UserDefaultsの便利な拡張
///
/// 型安全なプロパティアクセスを提供し、
/// キー文字列の直接使用を避けてタイポを防止します。
extension UserDefaults {
    // MARK: - Notification Settings

    /// 通知機能の有効/無効
    var notificationsEnabled: Bool {
        get { bool(forKey: UserDefaultsKeys.notificationsEnabled) }
        set { set(newValue, forKey: UserDefaultsKeys.notificationsEnabled) }
    }

    /// 残量少なし通知の閾値（パーセンテージ）
    /// デフォルト値: 10.0
    var lowStockThreshold: Double {
        get {
            let value = double(forKey: UserDefaultsKeys.lowStockThreshold)
            return value > 0 ? value : 10.0
        }
        set { set(newValue, forKey: UserDefaultsKeys.lowStockThreshold) }
    }

    /// 30日後通知の有効/無効
    var notifyAt30Days: Bool {
        get { bool(forKey: UserDefaultsKeys.notifyAt30Days) }
        set { set(newValue, forKey: UserDefaultsKeys.notifyAt30Days) }
    }

    /// 60日後通知の有効/無効
    var notifyAt60Days: Bool {
        get { bool(forKey: UserDefaultsKeys.notifyAt60Days) }
        set { set(newValue, forKey: UserDefaultsKeys.notifyAt60Days) }
    }

    /// 90日後通知の有効/無効
    var notifyAt90Days: Bool {
        get { bool(forKey: UserDefaultsKeys.notifyAt90Days) }
        set { set(newValue, forKey: UserDefaultsKeys.notifyAt90Days) }
    }

    // MARK: - CloudKit Settings

    /// CloudKitコンテナID
    var cloudKitContainerID: String? {
        get { string(forKey: UserDefaultsKeys.cloudKitContainerID) }
        set { set(newValue, forKey: UserDefaultsKeys.cloudKitContainerID) }
    }

    /// CloudKitスキーマ初期化済みフラグ
    var cloudKitSchemaInitialized: Bool {
        get { bool(forKey: UserDefaultsKeys.cloudKitSchemaInitialized) }
        set { set(newValue, forKey: UserDefaultsKeys.cloudKitSchemaInitialized) }
    }

    /// CloudKitスキーマ初期化日時
    var cloudKitSchemaInitializedDate: Date? {
        get { object(forKey: UserDefaultsKeys.cloudKitSchemaInitializedDate) as? Date }
        set { set(newValue, forKey: UserDefaultsKeys.cloudKitSchemaInitializedDate) }
    }

    // MARK: - Helper Methods

    /// CloudKit関連の設定をリセット
    func resetCloudKitSettings() {
        removeObject(forKey: UserDefaultsKeys.cloudKitSchemaInitialized)
        removeObject(forKey: UserDefaultsKeys.cloudKitSchemaInitializedDate)
    }
}
