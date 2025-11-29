import Foundation
import CoreData

/// 飲酒ログ管理サービス
///
/// 飲酒ログの作成、ボトル残量の更新、通知の再スケジュールを
/// 一元管理します。重複コードを排除し、一貫した動作を保証します。
class DrinkingLogService {
    /// シングルトンインスタンス
    static let shared = DrinkingLogService()

    private init() {}

    // MARK: - 飲酒ログ記録

    /// 飲酒を記録し、ボトルの残量を更新
    ///
    /// - Parameters:
    ///   - bottle: 対象のボトル
    ///   - volume: 消費量（ml）
    ///   - notes: メモ（デフォルト: "残量更新"）
    ///   - context: Core Dataコンテキスト
    /// - Throws: Core Data保存エラー
    func recordConsumption(
        bottle: Bottle,
        volume: Int32,
        notes: String = "残量更新",
        context: NSManagedObjectContext
    ) throws {
        // 未開栓の場合は開栓日を設定
        if bottle.openedDate == nil {
            bottle.openedDate = Date()
        }

        // 飲酒ログを作成
        let log = DrinkingLog(context: context)
        log.id = UUID()
        log.date = Date()
        log.volume = volume
        log.notes = notes
        log.createdAt = Date()
        log.bottle = bottle

        // 残量を減らす（0以下にはしない）
        bottle.remainingVolume = max(0, bottle.remainingVolume - volume)
        bottle.updatedAt = Date()

        try context.save()
    }

    /// 残量を直接更新（消費量が発生した場合のみログ作成）
    ///
    /// - Parameters:
    ///   - bottle: 対象のボトル
    ///   - newRemaining: 新しい残量（ml）
    ///   - context: Core Dataコンテキスト
    /// - Throws: Core Data保存エラー
    func updateRemainingVolume(
        bottle: Bottle,
        newRemaining: Int32,
        context: NSManagedObjectContext
    ) throws {
        let oldRemaining = bottle.remainingVolume
        let consumed = oldRemaining - newRemaining

        // 消費量が発生した場合のみ飲酒ログを作成
        if consumed > 0 {
            let log = DrinkingLog(context: context)
            log.id = UUID()
            log.date = Date()
            log.volume = consumed
            log.notes = "残量更新"
            log.createdAt = Date()
            log.bottle = bottle
        }

        bottle.remainingVolume = newRemaining
        bottle.updatedAt = Date()

        try context.save()
    }

    // MARK: - 1ショット消費

    /// 1ショット（30ml）を消費
    ///
    /// - Parameters:
    ///   - bottle: 対象のボトル
    ///   - context: Core Dataコンテキスト
    /// - Throws: Core Data保存エラー
    func consumeOneShot(
        bottle: Bottle,
        context: NSManagedObjectContext
    ) throws {
        try recordConsumption(
            bottle: bottle,
            volume: 30,
            notes: "1ショット消費",
            context: context
        )
    }

    // MARK: - 通知再スケジュール

    /// 全ボトルの通知を再スケジュール
    ///
    /// - Parameter context: Core Dataコンテキスト
    func rescheduleAllNotifications(context: NSManagedObjectContext) async {
        let request = NSFetchRequest<Bottle>(entityName: "Bottle")
        if let bottles = try? context.fetch(request) {
            await NotificationManager.shared.scheduleAllNotifications(for: bottles)
        }
    }

    /// 飲酒記録後の完全な処理（ログ作成＋通知再スケジュール）
    ///
    /// - Parameters:
    ///   - bottle: 対象のボトル
    ///   - volume: 消費量（ml）
    ///   - notes: メモ
    ///   - context: Core Dataコンテキスト
    /// - Throws: Core Data保存エラー
    func recordConsumptionAndReschedule(
        bottle: Bottle,
        volume: Int32,
        notes: String = "残量更新",
        context: NSManagedObjectContext
    ) async throws {
        try recordConsumption(
            bottle: bottle,
            volume: volume,
            notes: notes,
            context: context
        )
        await rescheduleAllNotifications(context: context)
    }
}
