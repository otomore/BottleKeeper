import SwiftUI
import CoreData

/// 統計画面のViewModel
///
/// ボトルコレクションの統計データを計算・管理します。
/// テスト容易性のため、Core Dataから取得したデータを外部から注入できます。
@MainActor
class StatisticsViewModel: ObservableObject {
    // MARK: - UI State

    @Published var consumptionPeriod: ConsumptionPeriod = .monthly
    @Published var selectedConsumption: (String, Int)?
    @Published var selectedType: String?

    // MARK: - Data

    private var bottles: [Bottle] = []
    private var drinkingLogs: [DrinkingLog] = []

    // MARK: - Initialization

    init() {}

    /// データを更新
    func updateData(bottles: [Bottle], drinkingLogs: [DrinkingLog]) {
        self.bottles = bottles
        self.drinkingLogs = drinkingLogs
        objectWillChange.send()
    }

    // MARK: - 基本統計

    var totalBottles: Int {
        bottles.count
    }

    var totalInvestment: Decimal {
        bottles.reduce(Decimal(0)) { sum, bottle in
            if let price = bottle.purchasePrice {
                return sum + price.decimalValue
            }
            return sum
        }
    }

    var averageABV: Double {
        guard !bottles.isEmpty else { return 0 }
        let total = bottles.reduce(0.0) { $0 + $1.abv }
        return total / Double(bottles.count)
    }

    // MARK: - 開栓状況

    var openedBottles: Int {
        bottles.filter { $0.isOpened }.count
    }

    var unopenedBottles: Int {
        bottles.filter { !$0.isOpened }.count
    }

    var openedPercentage: Double {
        guard totalBottles > 0 else { return 0 }
        return Double(openedBottles) / Double(totalBottles) * 100
    }

    var averageRemainingPercentage: Double {
        let openedBottlesArray = bottles.filter { $0.isOpened }
        guard !openedBottlesArray.isEmpty else { return 0 }
        let total = openedBottlesArray.reduce(0.0) { $0 + $1.remainingPercentage }
        return total / Double(openedBottlesArray.count)
    }

    var totalRemainingVolume: Int32 {
        bottles.reduce(0) { $0 + $1.remainingVolume }
    }

    // MARK: - タイプ別分布

    var typeDistribution: [(String, Int)] {
        let types = Dictionary(grouping: bottles) { $0.wrappedType }
        return types.map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    // MARK: - 消費データ

    var monthlyConsumption: [(String, Int)] {
        consumptionData(for: .month, count: 6, dateFormat: "M月")
    }

    var yearlyConsumption: [(String, Int)] {
        consumptionData(for: .year, count: 5, dateFormat: "yyyy年")
    }

    var currentConsumptionData: [(String, Int)] {
        consumptionPeriod == .monthly ? monthlyConsumption : yearlyConsumption
    }

    /// 期間別消費データを取得する汎用メソッド
    func consumptionData(for component: Calendar.Component, count: Int, dateFormat: String) -> [(String, Int)] {
        let calendar = Calendar.current
        let now = Date()

        let data = (0..<count).compactMap { offset -> (String, Int)? in
            guard let date = calendar.date(byAdding: component, value: -offset, to: now) else {
                return nil
            }

            let (start, end, label) = periodBounds(for: date, component: component, dateFormat: dateFormat)

            let consumption = drinkingLogs.filter { log in
                guard let logDate = log.date else { return false }
                return logDate >= start && logDate <= end
            }.reduce(0) { $0 + Int($1.volume) }

            return (label, consumption)
        }

        return data.reversed()
    }

    /// 期間の開始日・終了日・ラベルを取得
    func periodBounds(for date: Date, component: Calendar.Component, dateFormat: String) -> (Date, Date, String) {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")

        switch component {
        case .month:
            formatter.dateFormat = dateFormat
            let label = formatter.string(from: date)
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (start, end, label)

        case .year:
            let year = calendar.component(.year, from: date)
            let label = "\(year)年"
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!
            return (start, end, label)

        default:
            // サポートされていないコンポーネントの場合、月にフォールバック
            print("⚠️ Unsupported calendar component, falling back to month")
            formatter.dateFormat = dateFormat
            let label = formatter.string(from: date)
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (start, end, label)
        }
    }

    // MARK: - 消費トレンド統計

    func consumptionTrendStats(data: [(String, Int)]) -> (total: Int, average: Int) {
        let totalConsumption = data.reduce(0) { $0 + $1.1 }

        // 実際の消費期間を計算（初回消費日から現在まで）
        let avgConsumption: Int
        if let firstLog = drinkingLogs.last, let firstDate = firstLog.date {
            let calendar = Calendar.current
            let now = Date()

            let actualPeriods: Int
            if consumptionPeriod == .monthly {
                // 月数の差を計算
                let components = calendar.dateComponents([.month], from: firstDate, to: now)
                actualPeriods = max(1, (components.month ?? 0) + 1)
            } else {
                // 年数の差を計算
                let components = calendar.dateComponents([.year], from: firstDate, to: now)
                actualPeriods = max(1, (components.year ?? 0) + 1)
            }

            avgConsumption = totalConsumption / actualPeriods
        } else {
            avgConsumption = totalConsumption
        }

        return (totalConsumption, avgConsumption)
    }

    // MARK: - コストパフォーマンス

    var costPerformanceData: [(bottle: Bottle, pricePerMl: Decimal)] {
        bottles.compactMap { bottle in
            guard let price = bottle.purchasePrice,
                  bottle.volume > 0 else { return nil }
            let pricePerMl = price.decimalValue / Decimal(bottle.volume)
            return (bottle, pricePerMl)
        }
        .sorted { $0.pricePerMl < $1.pricePerMl }
    }

    // MARK: - 表示判定

    var hasBottles: Bool {
        !bottles.isEmpty
    }

    var hasTypeDistribution: Bool {
        !typeDistribution.isEmpty
    }

    var hasConsumptionData: Bool {
        let data = currentConsumptionData
        return !data.isEmpty && data.contains(where: { $0.1 > 0 })
    }

    var hasCostPerformanceData: Bool {
        !costPerformanceData.isEmpty
    }
}
