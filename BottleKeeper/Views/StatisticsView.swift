import SwiftUI
import CoreData
import Charts

struct StatisticsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bottle.createdAt, ascending: false)],
        animation: .default)
    private var bottles: FetchedResults<Bottle>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DrinkingLog.date, ascending: false)],
        animation: .default)
    private var drinkingLogs: FetchedResults<DrinkingLog>

    // 消費トレンドの表示モード
    @State private var consumptionPeriod: ConsumptionPeriod = .monthly
    @State private var selectedConsumption: (String, Int)?
    @State private var selectedType: String?

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

    var typeDistribution: [(String, Int)] {
        let types = Dictionary(grouping: bottles) { $0.wrappedType }
        return types.map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    var monthlyConsumption: [(String, Int)] {
        consumptionData(for: .month, count: 6, dateFormat: "M月")
    }

    var yearlyConsumption: [(String, Int)] {
        consumptionData(for: .year, count: 5, dateFormat: "yyyy年")
    }

    /// 期間別消費データを取得する汎用メソッド
    private func consumptionData(for component: Calendar.Component, count: Int, dateFormat: String) -> [(String, Int)] {
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
    private func periodBounds(for date: Date, component: Calendar.Component, dateFormat: String) -> (Date, Date, String) {
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

    var averageRemainingPercentage: Double {
        let openedBottlesArray = bottles.filter { $0.isOpened }
        guard !openedBottlesArray.isEmpty else { return 0 }
        let total = openedBottlesArray.reduce(0.0) { $0 + $1.remainingPercentage }
        return total / Double(openedBottlesArray.count)
    }

    var totalRemainingVolume: Int32 {
        bottles.reduce(0) { $0 + $1.remainingVolume }
    }

    // コストパフォーマンス分析（ml単価順）
    var costPerformanceData: [(bottle: Bottle, pricePerMl: Decimal)] {
        bottles.compactMap { bottle in
            guard let price = bottle.purchasePrice,
                  bottle.volume > 0 else { return nil }
            let pricePerMl = price.decimalValue / Decimal(bottle.volume)
            return (bottle, pricePerMl)
        }
        .sorted { $0.pricePerMl < $1.pricePerMl }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if bottles.isEmpty {
                    emptyStateView
                } else {
                    statisticsContentView
                }
            }
            .navigationTitle("統計")
        }
    }

    // MARK: - サブビュー

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding(.top, 60)

            Text("統計情報がありません")
                .font(.headline)
                .foregroundColor(.gray)

            Text("ボトルを追加すると統計が表示されます")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var statisticsContentView: some View {
        VStack(spacing: 20) {
            basicStatsSection
            openedStatusSection
            typeDistributionSection
            consumptionTrendSection
            costPerformanceSection
        }
        .padding(.vertical)
    }

    private var basicStatsSection: some View {
        VStack(spacing: 16) {
            Text("コレクション概要")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCardView(
                    title: "総ボトル数",
                    value: "\(totalBottles)",
                    icon: "wineglass.fill",
                    color: .blue
                )

                StatCardView(
                    title: "総投資額",
                    value: "¥\(Int(truncating: totalInvestment as NSNumber))",
                    icon: "yensign.circle.fill",
                    color: .green
                )

                StatCardView(
                    title: "平均ABV",
                    value: String(format: "%.1f%%", averageABV),
                    icon: "percent",
                    color: .orange
                )

                StatCardView(
                    title: "開栓率",
                    value: String(format: "%.0f%%", openedPercentage),
                    icon: "seal.fill",
                    color: .purple
                )
            }
        }
        .padding()
    }

    private var openedStatusSection: some View {
        VStack(spacing: 16) {
            Text("開栓状況")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 20) {
                VStack {
                    Text("\(openedBottles)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("開栓済み")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .subtleGlassEffect(tint: .orange)

                VStack {
                    Text("\(unopenedBottles)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("未開栓")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .subtleGlassEffect(tint: .green)
            }

            if openedBottles > 0 {
                averageRemainingView
            }

            totalRemainingView
        }
        .padding()
    }

    private var averageRemainingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("平均残量")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ProgressView(value: averageRemainingPercentage, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))

            Text("\(averageRemainingPercentage, specifier: "%.1f")%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .subtleGlassEffect(tint: .gray)
    }

    private var totalRemainingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("総残量")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(totalRemainingVolume)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                Text("ml")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Text("全ボトルの合計残量")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .subtleGlassEffect(tint: .orange)
    }

    @ViewBuilder
    private var typeDistributionSection: some View {
        if !typeDistribution.isEmpty {
            VStack(spacing: 16) {
                Text("タイプ別分布")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                typeDistributionChart
                typeDistributionDetails
            }
            .padding()
        }
    }

    private var typeDistributionChart: some View {
        Chart(typeDistribution, id: \.0) { type, count in
            SectorMark(
                angle: .value("本数", count),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(by: .value("タイプ", type))
            .opacity(selectedType == nil || selectedType == type ? 1.0 : 0.5)
            .annotation(position: .overlay) {
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .frame(height: 250)
        .chartLegend(position: .bottom, alignment: .center, spacing: 10)
        .chartAngleSelection(value: $selectedType)
    }

    @ViewBuilder
    private var typeDistributionDetails: some View {
        if let selected = selectedType,
           let selectedData = typeDistribution.first(where: { $0.0 == selected }) {
            VStack(spacing: 8) {
                Text("\(selectedData.0)の詳細")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack {
                    Text("本数:")
                    Spacer()
                    Text("\(selectedData.1)本")
                        .fontWeight(.bold)
                }
                HStack {
                    Text("割合:")
                    Spacer()
                    Text("\(Double(selectedData.1) / Double(totalBottles) * 100, specifier: "%.1f")%")
                        .fontWeight(.bold)
                }
            }
            .padding()
            .subtleGlassEffect(tint: .orange)
        }

        VStack(spacing: 8) {
            ForEach(typeDistribution, id: \.0) { type, count in
                HStack {
                    Text(type)
                        .font(.subheadline)

                    Spacer()

                    Text("\(count)本")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("(\(Double(count) / Double(totalBottles) * 100, specifier: "%.0f")%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .subtleGlassEffect(tint: .gray)
    }

    @ViewBuilder
    private var consumptionTrendSection: some View {
        let consumptionData = consumptionPeriod == .monthly ? monthlyConsumption : yearlyConsumption
        if !consumptionData.isEmpty && consumptionData.contains(where: { $0.1 > 0 }) {
            VStack(spacing: 16) {
                consumptionTrendHeader
                consumptionTrendChart(data: consumptionData)
                consumptionTrendStats(data: consumptionData)
            }
            .padding()
        }
    }

    private var consumptionTrendHeader: some View {
        HStack {
            Text("消費トレンド")
                .font(.headline)

            Spacer()

            Picker("期間", selection: $consumptionPeriod) {
                Text("月次").tag(ConsumptionPeriod.monthly)
                Text("年次").tag(ConsumptionPeriod.yearly)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
    }

    private func consumptionTrendChart(data: [(String, Int)]) -> some View {
        VStack(spacing: 8) {
            Chart(data, id: \.0) { period, volume in
                BarMark(
                    x: .value(consumptionPeriod == .monthly ? "月" : "年", period),
                    y: .value("消費量", volume)
                )
                .foregroundStyle(
                    selectedConsumption?.0 == period
                        ? Color.orange.gradient
                        : Color.blue.gradient
                )
                .annotation(position: .top) {
                    if volume > 0 {
                        Text("\(volume)ml")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)ml")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }

            if let selected = selectedConsumption {
                VStack(spacing: 8) {
                    Text("\(selected.0)の詳細")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    HStack {
                        Text("消費量:")
                        Spacer()
                        Text("\(selected.1)ml")
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .subtleGlassEffect(tint: .orange)
            }
        }
    }

    private func consumptionTrendStats(data: [(String, Int)]) -> some View {
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
                actualPeriods = max(1, (components.month ?? 0) + 1) // 最低1ヶ月
            } else {
                // 年数の差を計算
                let components = calendar.dateComponents([.year], from: firstDate, to: now)
                actualPeriods = max(1, (components.year ?? 0) + 1) // 最低1年
            }

            avgConsumption = totalConsumption / actualPeriods
        } else {
            avgConsumption = totalConsumption
        }

        return HStack(spacing: 20) {
            VStack {
                Text("\(totalConsumption)ml")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("合計消費量")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .subtleGlassEffect(tint: .blue)

            VStack {
                Text("\(avgConsumption)ml")
                    .font(.title3)
                    .fontWeight(.bold)
                Text(consumptionPeriod == .monthly ? "月平均" : "年平均")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .subtleGlassEffect(tint: .green)
        }
    }

    @ViewBuilder
    private var costPerformanceSection: some View {
        if !costPerformanceData.isEmpty {
            VStack(spacing: 16) {
                Text("コストパフォーマンス分析")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    ForEach(Array(costPerformanceData.prefix(10).enumerated()), id: \.element.bottle.id) { index, data in
                        CostPerformanceRow(index: index, bottle: data.bottle, pricePerMl: data.pricePerMl)
                    }
                }

                if costPerformanceData.count > 10 {
                    Text("上位10件を表示中（全\(costPerformanceData.count)件）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding()
        }
    }
}

#Preview {
    StatisticsView()
        .environment(\.managedObjectContext, CoreDataManager.preview.container.viewContext)
}
