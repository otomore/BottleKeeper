import Foundation
import UserNotifications
import CoreData

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // 通知権限をリクエスト
    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // 通知権限の状態を確認
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // 全ての通知をスケジュール
    func scheduleAllNotifications(for bottles: [Bottle]) async {
        // 既存の通知をクリア
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        for bottle in bottles {
            // 残量少なし通知
            scheduleLowStockNotification(for: bottle)

            // 開栓後経過日数通知（30日、60日、90日）
            scheduleAgeNotification(for: bottle)
        }
    }

    // 残量少なし通知（残量設定値以下）
    private func scheduleLowStockNotification(for bottle: Bottle) {
        // UserDefaultsから設定を取得
        guard UserDefaults.standard.notificationsEnabled else { return }

        let lowStockThreshold = UserDefaults.standard.lowStockThreshold

        guard bottle.isOpened, bottle.remainingPercentage <= lowStockThreshold, bottle.remainingPercentage > 0 else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "残量が少なくなっています"
        content.body = "\(bottle.wrappedName)の残量が\(Int(bottle.remainingPercentage))%です。"
        content.sound = .default
        content.categoryIdentifier = "LOW_STOCK"
        content.userInfo = ["bottleId": bottle.id?.uuidString ?? ""]

        // 即座に通知（実際には数秒後）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let identifier = "low_stock_\(bottle.id?.uuidString ?? UUID().uuidString)"

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知のスケジュールに失敗: \(error)")
            }
        }
    }

    // 開栓後経過日数通知
    private func scheduleAgeNotification(for bottle: Bottle) {
        // UserDefaultsから設定を取得
        guard UserDefaults.standard.notificationsEnabled else { return }

        guard let openedDate = bottle.openedDate else {
            return
        }

        let calendar = Calendar.current
        let now = Date()

        // 開栓からの日数を計算
        let components = calendar.dateComponents([.day], from: openedDate, to: now)
        guard let daysSinceOpened = components.day else { return }

        // UserDefaultsから有効な通知日数を取得
        var thresholds: [Int] = []
        if UserDefaults.standard.notifyAt30Days {
            thresholds.append(30)
        }
        if UserDefaults.standard.notifyAt60Days {
            thresholds.append(60)
        }
        if UserDefaults.standard.notifyAt90Days {
            thresholds.append(90)
        }

        guard !thresholds.isEmpty else { return }

        for threshold in thresholds {
            // すでに閾値を過ぎている場合、次の閾値へ
            if daysSinceOpened < threshold {
                // 閾値に達する日付を計算
                guard let notificationDate = calendar.date(byAdding: .day, value: threshold, to: openedDate) else {
                    continue
                }

                // すでに過去の日付の場合はスキップ
                if notificationDate <= now {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = "開栓から\(threshold)日経過"
                content.body = "\(bottle.wrappedName)を開栓してから\(threshold)日が経過しました。"
                content.sound = .default
                content.categoryIdentifier = "AGE_NOTIFICATION"
                content.userInfo = ["bottleId": bottle.id?.uuidString ?? "", "days": threshold]

                // 通知日時のトリガーを作成
                let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
                let identifier = "age_\(threshold)_\(bottle.id?.uuidString ?? UUID().uuidString)"

                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("通知のスケジュールに失敗: \(error)")
                    }
                }
            }
        }
    }

    // 特定のボトルの通知をキャンセル
    func cancelNotifications(for bottle: Bottle) {
        guard let bottleId = bottle.id?.uuidString else { return }

        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToCancel = requests
                .filter { $0.content.userInfo["bottleId"] as? String == bottleId }
                .map { $0.identifier }

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
        }
    }

    // UNUserNotificationCenterDelegateメソッド
    // アプリがフォアグラウンドにあるときも通知を表示
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // 通知をタップしたときの処理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let bottleIdString = userInfo["bottleId"] as? String,
           let bottleId = UUID(uuidString: bottleIdString) {
            // ボトル詳細画面を開く処理（NotificationCenterを使って通知）
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenBottleDetail"),
                object: nil,
                userInfo: ["bottleId": bottleId]
            )
        }

        completionHandler()
    }

    // デバッグ用：ペンディング中の通知を表示
    func printPendingNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        print("ペンディング中の通知: \(requests.count)件")
        for request in requests {
            print("- \(request.identifier): \(request.content.title)")
        }
    }
}
