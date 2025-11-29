import SwiftUI
import CoreData

/// 設定画面のViewModel
///
/// iCloud同期状態の管理、CloudKitスキーマの初期化、
/// データ削除などの設定関連の操作を処理します。
@MainActor
class SettingsViewModel: ObservableObject {
    @Published var showingDeleteAlert = false
    @Published var iCloudSyncAvailable = false
    @Published var showingSchemaInitAlert = false
    @Published var schemaInitError: String?
    @Published var isInitializingSchema = false

    private let coreDataManager: CoreDataManager

    init(coreDataManager: CoreDataManager = .shared) {
        self.coreDataManager = coreDataManager
        self.iCloudSyncAvailable = coreDataManager.isCloudSyncAvailable
    }

    var isCloudKitSchemaInitialized: Bool {
        coreDataManager.isCloudKitSchemaInitialized
    }

    var cloudKitLogs: [String] {
        coreDataManager.logs
    }

    /// すべてのデータを削除
    func deleteAllData(bottles: FetchedResults<Bottle>, wishlistItems: FetchedResults<WishlistItem>, context: NSManagedObjectContext) {
        guard !bottles.isEmpty || !wishlistItems.isEmpty else {
            print("ℹ️ No data to delete")
            return
        }

        let bottleCount = bottles.count
        let wishlistCount = wishlistItems.count

        // すべてのボトルを削除
        bottles.forEach { bottle in
            context.delete(bottle)
        }

        // すべてのウィッシュリストアイテムを削除
        wishlistItems.forEach { item in
            context.delete(item)
        }

        do {
            try context.save()
            print("✅ Deleted \(bottleCount) bottles and \(wishlistCount) wishlist items")
        } catch {
            let nsError = error as NSError
            print("❌ Failed to delete all data: \(nsError), \(nsError.userInfo)")

            // コンテキストをロールバックして変更を元に戻す
            context.rollback()
        }
    }

    /// CloudKitスキーマを初期化
    func initializeCloudKitSchema() {
        isInitializingSchema = true
        schemaInitError = nil

        Task {
            do {
                try coreDataManager.initializeCloudKitSchema()
                await MainActor.run {
                    isInitializingSchema = false
                    showingSchemaInitAlert = true
                }
            } catch {
                await MainActor.run {
                    isInitializingSchema = false
                    schemaInitError = error.localizedDescription
                    showingSchemaInitAlert = true
                }
            }
        }
    }

    /// iCloud同期状態を更新
    func refreshCloudSyncStatus() {
        iCloudSyncAvailable = coreDataManager.isCloudSyncAvailable
    }

    /// CloudKit診断情報を表示
    func showDiagnosticInfo() {
        let diagnosticInfo = coreDataManager.diagnosticCloudKitStatus()
        print(diagnosticInfo)
    }

    /// iCloud状態を再確認
    func recheckiCloudStatus() {
        coreDataManager.recheckiCloudStatus()
        refreshCloudSyncStatus()
    }
}
