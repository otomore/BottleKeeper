import SwiftUI
import CoreData

/// ボトルリスト画面のViewModel
///
/// ボトルのフィルタリング、削除、ランダム選択などのロジックを管理します。
/// テスト容易性のため、依存性を外部から注入できる設計です。
@MainActor
class BottleListViewModel: ObservableObject {
    // MARK: - UI State

    @Published var showingAddBottle = false
    @Published var showingQuickUpdate = false
    @Published var showingBottleDetail = false
    @Published var showingRandomPicker = false
    @Published var navigateToRandomBottle = false
    @Published var searchText = ""
    @Published var selectedBottle: Bottle?
    @Published var randomBottle: Bottle?
    @Published var filteredBottles: [Bottle] = []

    // MARK: - Dependencies

    private let drinkingLogService: DrinkingLogService

    // MARK: - Data

    private var bottles: [Bottle] = []

    // MARK: - Initialization

    init(drinkingLogService: DrinkingLogService = .shared) {
        self.drinkingLogService = drinkingLogService
    }

    // MARK: - Data Management

    /// ボトルデータを更新
    func updateBottles(_ bottles: [Bottle]) {
        self.bottles = bottles
        updateFilteredBottles()
    }

    /// フィルタリングされたボトルリストを更新
    func updateFilteredBottles() {
        filteredBottles = bottles.filtered(by: searchText)
    }

    // MARK: - Actions

    /// 1ショット消費
    func consumeOneShot(_ bottle: Bottle, context: NSManagedObjectContext) {
        do {
            try drinkingLogService.consumeOneShot(
                bottle: bottle,
                context: context
            )

            // 通知を再スケジュール
            Task {
                await drinkingLogService.rescheduleAllNotifications(context: context)
            }
        } catch {
            let nsError = error as NSError
            print("⚠️ Failed to consume one shot: \(nsError), \(nsError.userInfo)")
        }
    }

    /// ボトルを削除
    func deleteBottle(_ bottle: Bottle, context: NSManagedObjectContext) {
        context.delete(bottle)

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("⚠️ Failed to delete bottle: \(nsError), \(nsError.userInfo)")
        }
    }

    /// インデックスセットからボトルを削除
    func deleteBottles(at offsets: IndexSet, context: NSManagedObjectContext) {
        offsets.map { filteredBottles[$0] }.forEach(context.delete)

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("⚠️ Failed to delete bottles: \(nsError), \(nsError.userInfo)")
        }
    }

    /// ランダムにボトルを選択
    func pickRandomBottle() {
        guard !bottles.isEmpty else { return }
        randomBottle = bottles.randomElement()
        showingRandomPicker = true
    }

    /// ボトル追加画面を表示
    func showAddBottle() {
        showingAddBottle = true
    }

    /// クイック更新画面を表示
    func showQuickUpdate(for bottle: Bottle) {
        selectedBottle = bottle
        showingQuickUpdate = true
    }

    /// ボトル詳細画面を表示
    func showBottleDetail(for bottle: Bottle) {
        selectedBottle = bottle
        showingBottleDetail = true
    }

    /// ランダム選択結果の詳細へ遷移
    func navigateToRandomBottleDetail() {
        navigateToRandomBottle = true
    }

    // MARK: - Layout Helpers

    /// 画面幅に応じたグリッド列数を計算
    func gridColumns(for width: CGFloat) -> Int {
        if width >= 1000 {
            return 3  // iPad横向き
        } else if width >= 700 {
            return 2  // iPad縦向き
        } else {
            return 1  // iPhone
        }
    }

    // MARK: - State Helpers

    var hasBottles: Bool {
        !bottles.isEmpty
    }

    var hasFilteredBottles: Bool {
        !filteredBottles.isEmpty
    }
}
