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

    @StateObject private var viewModel = StatisticsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if !viewModel.hasBottles {
                    emptyStateView
                } else {
                    statisticsContentView
                }
            }
            .navigationTitle("統計")
        }
        .onAppear {
            viewModel.updateData(bottles: Array(bottles), drinkingLogs: Array(drinkingLogs))
        }
        .onChange(of: bottles.count) { _, _ in
            viewModel.updateData(bottles: Array(bottles), drinkingLogs: Array(drinkingLogs))
        }
        .onChange(of: drinkingLogs.count) { _, _ in
            viewModel.updateData(bottles: Array(bottles), drinkingLogs: Array(drinkingLogs))
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
                    value: "\(viewModel.totalBottles)",
                    icon: "wineglass.fill",
                    color: .blue
                )

                StatCardView(
                    title: "総投資額",
                    value: "¥\(Int(truncating: viewModel.totalInvestment as NSNumber))",
                    icon: "yensign.circle.fill",
                    color: .green
                )

                StatCardView(
                    title: "平均ABV",
                    value: String(format: "%.1f%%", viewModel.averageABV),
                    icon: "percent",
                    color: .orange
                )

                StatCardView(
                    title: "開栓率",
                    value: String(format: "%.0f%%", viewModel.openedPercentage),
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
                    Text("\(viewModel.openedBottles)")
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
                    Text("\(viewModel.unopenedBottles)")
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

            if viewModel.openedBottles > 0 {
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

            ProgressView(value: viewModel.averageRemainingPercentage, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))

            Text("\(viewModel.averageRemainingPercentage, specifier: "%.1f")%")
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
                Text("\(viewModel.totalRemainingVolume)")
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
        if viewModel.hasTypeDistribution {
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
        Chart(viewModel.typeDistribution, id: \.0) { type, count in
            SectorMark(
                angle: .value("本数", count),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(by: .value("タイプ", type))
            .opacity(viewModel.selectedType == nil || viewModel.selectedType == type ? 1.0 : 0.5)
            .annotation(position: .overlay) {
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .frame(height: 250)
        .chartLegend(position: .bottom, alignment: .center, spacing: 10)
        .chartAngleSelection(value: $viewModel.selectedType)
    }

    @ViewBuilder
    private var typeDistributionDetails: some View {
        if let selected = viewModel.selectedType,
           let selectedData = viewModel.typeDistribution.first(where: { $0.0 == selected }) {
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
                    Text("\(Double(selectedData.1) / Double(viewModel.totalBottles) * 100, specifier: "%.1f")%")
                        .fontWeight(.bold)
                }
            }
            .padding()
            .subtleGlassEffect(tint: .orange)
        }

        VStack(spacing: 8) {
            ForEach(viewModel.typeDistribution, id: \.0) { type, count in
                HStack {
                    Text(type)
                        .font(.subheadline)

                    Spacer()

                    Text("\(count)本")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("(\(Double(count) / Double(viewModel.totalBottles) * 100, specifier: "%.0f")%)")
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
        if viewModel.hasConsumptionData {
            VStack(spacing: 16) {
                consumptionTrendHeader
                consumptionTrendChart(data: viewModel.currentConsumptionData)
                consumptionTrendStats(data: viewModel.currentConsumptionData)
            }
            .padding()
        }
    }

    private var consumptionTrendHeader: some View {
        HStack {
            Text("消費トレンド")
                .font(.headline)

            Spacer()

            Picker("期間", selection: $viewModel.consumptionPeriod) {
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
                    x: .value(viewModel.consumptionPeriod == .monthly ? "月" : "年", period),
                    y: .value("消費量", volume)
                )
                .foregroundStyle(
                    viewModel.selectedConsumption?.0 == period
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

            if let selected = viewModel.selectedConsumption {
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
        let stats = viewModel.consumptionTrendStats(data: data)

        return HStack(spacing: 20) {
            VStack {
                Text("\(stats.total)ml")
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
                Text("\(stats.average)ml")
                    .font(.title3)
                    .fontWeight(.bold)
                Text(viewModel.consumptionPeriod == .monthly ? "月平均" : "年平均")
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
        if viewModel.hasCostPerformanceData {
            VStack(spacing: 16) {
                Text("コストパフォーマンス分析")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    ForEach(Array(viewModel.costPerformanceData.prefix(10).enumerated()), id: \.element.bottle.id) { index, data in
                        CostPerformanceRow(index: index, bottle: data.bottle, pricePerMl: data.pricePerMl)
                    }
                }

                if viewModel.costPerformanceData.count > 10 {
                    Text("上位10件を表示中（全\(viewModel.costPerformanceData.count)件）")
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
