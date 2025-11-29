import SwiftUI
import CoreData

struct BottleListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var motionManager = MotionManager()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bottle.updatedAt, ascending: false)],
        animation: .default)
    private var bottles: FetchedResults<Bottle>

    @State private var showingAddBottle = false
    @State private var searchText = ""
    @State private var showingQuickUpdate = false
    @State private var selectedBottle: Bottle?
    @State private var filteredBottles: [Bottle] = []
    @State private var randomBottle: Bottle?
    @State private var showingRandomPicker = false
    @State private var navigateToRandomBottle = false
    @State private var showingBottleDetail = false

    private func updateFilteredBottles() {
        filteredBottles = bottles.filtered(by: searchText)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                GeometryReader { geometry in
                    Group {
                        if bottles.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "wineglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)

                                Text("ボトルが登録されていません")
                                    .font(.headline)
                                    .foregroundColor(.gray)

                                Text("右上の+ボタンから新しいボトルを登録しましょう")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                Button {
                                    showingAddBottle = true
                                } label: {
                                    Label("ボトルを追加", systemImage: "plus.circle.fill")
                                        .font(.headline)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            bottleListContent(geometry: geometry)
                                .searchable(text: $searchText, prompt: "銘柄名や蒸留所で検索")
                        }
                    }
                }

                // フローティングボタン（ランダム選択）
                if !bottles.isEmpty {
                    Button {
                        pickRandomBottle()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("コレクション")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddBottle = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                if !bottles.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddBottle) {
                BottleFormView(bottle: nil)
            }
            .sheet(isPresented: $showingQuickUpdate) {
                if let bottle = selectedBottle {
                    QuickUpdateView(bottle: bottle)
                }
            }
            .sheet(isPresented: $showingBottleDetail) {
                if let bottle = selectedBottle {
                    NavigationStack {
                        BottleDetailView(bottle: bottle)
                    }
                }
            }
            .alert("今日のおすすめボトル", isPresented: $showingRandomPicker) {
                Button("詳細を見る") {
                    navigateToRandomBottle = true
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                if let bottle = randomBottle {
                    Text("今日は「\(bottle.wrappedName)」を楽しんでみませんか？\n蒸留所: \(bottle.wrappedDistillery)")
                }
            }
            .background {
                NavigationLink(
                    destination: randomBottle.map { BottleDetailView(bottle: $0) },
                    isActive: $navigateToRandomBottle
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .onAppear {
                updateFilteredBottles()
            }
            .onChange(of: searchText) { _, _ in
                updateFilteredBottles()
            }
            .onChange(of: bottles.count) { _, _ in
                updateFilteredBottles()
            }
        }
    }

    private func consumeOneShot(_ bottle: Bottle) {
        withAnimation {
            do {
                try DrinkingLogService.shared.consumeOneShot(
                    bottle: bottle,
                    context: viewContext
                )

                // 通知を再スケジュール
                Task {
                    await DrinkingLogService.shared.rescheduleAllNotifications(context: viewContext)
                }
            } catch {
                let nsError = error as NSError
                print("⚠️ Failed to consume one shot: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteBottle(_ bottle: Bottle) {
        withAnimation {
            viewContext.delete(bottle)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("⚠️ Failed to delete bottle: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteBottles(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredBottles[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("⚠️ Failed to delete bottles: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func pickRandomBottle() {
        guard !bottles.isEmpty else { return }
        randomBottle = bottles.randomElement()
        showingRandomPicker = true
    }

    @ViewBuilder
    private func bottleListContent(geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let columns = gridColumns(for: width)

        if columns > 1 {
            // iPad: グリッドレイアウト
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns), spacing: 16) {
                    ForEach(filteredBottles, id: \.id) { bottle in
                        Button {
                            selectedBottle = bottle
                            showingBottleDetail = true
                        } label: {
                            BottleRowView(bottle: bottle, motionManager: motionManager)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                selectedBottle = bottle
                                showingQuickUpdate = true
                            } label: {
                                Label("残量更新", systemImage: "drop.fill")
                            }

                            Button {
                                consumeOneShot(bottle)
                            } label: {
                                Label("1ショット消費", systemImage: "minus.circle")
                            }

                            Button(role: .destructive) {
                                deleteBottle(bottle)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        } else {
            // iPhone: リストレイアウト
            List {
                ForEach(filteredBottles, id: \.id) { bottle in
                    Button {
                        selectedBottle = bottle
                        showingBottleDetail = true
                    } label: {
                        BottleRowView(bottle: bottle, motionManager: motionManager)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .onLongPressGesture {
                        selectedBottle = bottle
                        showingQuickUpdate = true
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            consumeOneShot(bottle)
                        } label: {
                            Label("1ショット", systemImage: "drop.fill")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteBottle(bottle)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteBottles)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func gridColumns(for width: CGFloat) -> Int {
        if width >= 1000 {
            return 3  // iPad横向き
        } else if width >= 700 {
            return 2  // iPad縦向き
        } else {
            return 1  // iPhone
        }
    }
}

struct BottleRowView: View {
    let bottle: Bottle
    @ObservedObject var motionManager: MotionManager

    var body: some View {
        HStack(spacing: 12) {
            // ボトル形状のビュー
            BottleShapeView(
                remainingPercentage: bottle.remainingPercentage / 100.0,
                motionManager: motionManager
            )
            .frame(width: 50, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(bottle.wrappedName)
                    .font(.headline)

                Text(bottle.wrappedDistillery)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    // 開栓ステータス
                    if bottle.isOpened {
                        Label("\(bottle.remainingPercentage, specifier: "%.0f")%", systemImage: "drop.fill")
                            .font(.caption)
                            .foregroundColor(remainingColor(for: bottle.remainingPercentage))
                    } else {
                        Label("未開栓", systemImage: "seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    // レーティング
                    if bottle.rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                            Text("\(bottle.rating)")
                                .font(.caption)
                        }
                        .foregroundColor(.yellow)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .subtleGlassEffect(tint: .blue)
    }

    private func remainingColor(for percentage: Double) -> Color {
        AppColors.remainingColor(for: percentage)
    }
}

// ボトル形状のカスタムビュー
struct BottleShapeView: View {
    let remainingPercentage: Double // 0.0 ~ 1.0
    @ObservedObject var motionManager: MotionManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var wavePhase: Double = 0

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                ZStack(alignment: .bottom) {
                    // ボトルの輪郭
                    BottleOutlineShape()
                        .stroke(AppColors.bottleOutline(for: colorScheme), lineWidth: 2)

                    // ボトルの背景
                    BottleOutlineShape()
                        .fill(AppColors.bottleBackground(for: colorScheme))

                    // 液体の部分
                    LiquidWaveShape(
                        liquidHeight: remainingPercentage,
                        tiltOffset: motionManager.roll * 45,
                        wavePhase: wavePhase,
                        waveAmplitude: min(motionManager.accelerationMagnitude * 8, 3.0)
                    )
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: AppColors.whiskyLiquid(for: colorScheme)),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(BottleOutlineShape()) // ボトルの形に切り抜く
                }
                .onChange(of: timeline.date) { _ in
                    wavePhase += 0.05
                }
            }
        }
    }
}

// ボトルの輪郭を描画するShape
struct BottleOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        // ボトルの首部分（上部20%）
        let neckWidth = width * 0.4
        let neckHeight = height * 0.2

        // ボトルの胴体部分（中央60%）
        let bodyWidth = width * 0.8
        let bodyHeight = height * 0.6

        // ボトルの底部分（下部20%）
        let bottomWidth = width * 0.7
        let bottomHeight = height * 0.2

        // 描画開始（左上）
        path.move(to: CGPoint(x: (width - neckWidth) / 2, y: 0))

        // 首の右側
        path.addLine(to: CGPoint(x: (width + neckWidth) / 2, y: 0))
        path.addLine(to: CGPoint(x: (width + neckWidth) / 2, y: neckHeight))

        // 肩の部分（曲線）
        path.addQuadCurve(
            to: CGPoint(x: (width + bodyWidth) / 2, y: neckHeight + 10),
            control: CGPoint(x: (width + bodyWidth) / 2, y: neckHeight)
        )

        // 胴体の右側
        path.addLine(to: CGPoint(x: (width + bodyWidth) / 2, y: neckHeight + bodyHeight))

        // 底への移行（曲線）
        path.addQuadCurve(
            to: CGPoint(x: (width + bottomWidth) / 2, y: neckHeight + bodyHeight + 10),
            control: CGPoint(x: (width + bodyWidth) / 2, y: neckHeight + bodyHeight + 5)
        )

        // 底の右側
        path.addLine(to: CGPoint(x: (width + bottomWidth) / 2, y: height))

        // 底辺
        path.addLine(to: CGPoint(x: (width - bottomWidth) / 2, y: height))

        // 底の左側
        path.addLine(to: CGPoint(x: (width - bottomWidth) / 2, y: neckHeight + bodyHeight + 10))

        // 胴体への移行（曲線）
        path.addQuadCurve(
            to: CGPoint(x: (width - bodyWidth) / 2, y: neckHeight + bodyHeight),
            control: CGPoint(x: (width - bodyWidth) / 2, y: neckHeight + bodyHeight + 5)
        )

        // 胴体の左側
        path.addLine(to: CGPoint(x: (width - bodyWidth) / 2, y: neckHeight + 10))

        // 肩の部分（曲線）
        path.addQuadCurve(
            to: CGPoint(x: (width - neckWidth) / 2, y: neckHeight),
            control: CGPoint(x: (width - bodyWidth) / 2, y: neckHeight)
        )

        // 首の左側
        path.addLine(to: CGPoint(x: (width - neckWidth) / 2, y: 0))

        path.closeSubpath()
        return path
    }
}

// 波動を持つ液体を描画するShape
struct LiquidWaveShape: Shape {
    var liquidHeight: Double // 0.0 ~ 1.0
    var tiltOffset: Double // 傾きによるオフセット
    var wavePhase: Double // 波の位相
    var waveAmplitude: Double // 波の振幅

    var animatableData: AnimatableDataQuad {
        get {
            AnimatableDataQuad(
                first: liquidHeight,
                second: tiltOffset,
                third: wavePhase,
                fourth: waveAmplitude
            )
        }
        set {
            liquidHeight = newValue.first
            tiltOffset = newValue.second
            wavePhase = newValue.third
            waveAmplitude = newValue.fourth
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        let liquidLevel = height * (1 - liquidHeight)

        // 波のパラメータ
        let waveFrequency = 2.0 * .pi / width // 波の周波数
        let segments = 50 // 波の精度

        // 液体の表面（波形を描画）
        for i in 0...segments {
            let x = width * Double(i) / Double(segments)

            // 傾きによる基本オフセット
            let tiltY = liquidLevel + tiltOffset * (1.0 - 2.0 * x / width)

            // 波動を追加
            let waveY = sin(x * waveFrequency + wavePhase) * waveAmplitude

            let y = tiltY + waveY

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // 底辺までパスを閉じる
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}

// AnimatableDataを4つのDoubleに拡張
struct AnimatableDataQuad: VectorArithmetic {
    var first: Double
    var second: Double
    var third: Double
    var fourth: Double

    static var zero = AnimatableDataQuad(first: 0, second: 0, third: 0, fourth: 0)

    static func + (lhs: AnimatableDataQuad, rhs: AnimatableDataQuad) -> AnimatableDataQuad {
        AnimatableDataQuad(
            first: lhs.first + rhs.first,
            second: lhs.second + rhs.second,
            third: lhs.third + rhs.third,
            fourth: lhs.fourth + rhs.fourth
        )
    }

    static func - (lhs: AnimatableDataQuad, rhs: AnimatableDataQuad) -> AnimatableDataQuad {
        AnimatableDataQuad(
            first: lhs.first - rhs.first,
            second: lhs.second - rhs.second,
            third: lhs.third - rhs.third,
            fourth: lhs.fourth - rhs.fourth
        )
    }

    mutating func scale(by rhs: Double) {
        first *= rhs
        second *= rhs
        third *= rhs
        fourth *= rhs
    }

    var magnitudeSquared: Double {
        first * first + second * second + third * third + fourth * fourth
    }
}

// 液体を描画するShape（旧バージョン - 参考用に残す）
struct LiquidShape: Shape {
    var liquidHeight: Double // 0.0 ~ 1.0
    var tiltOffset: Double // 傾きによるオフセット

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(liquidHeight, tiltOffset) }
        set {
            liquidHeight = newValue.first
            tiltOffset = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        let liquidLevel = height * (1 - liquidHeight)

        // 傾きによる左右のオフセット（方向を反転し、増幅率を上げる）
        let leftOffset = tiltOffset
        let rightOffset = -tiltOffset

        // 液体の表面（傾きを考慮）
        path.move(to: CGPoint(x: 0, y: liquidLevel + leftOffset))
        path.addLine(to: CGPoint(x: width, y: liquidLevel + rightOffset))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}

// 残量クイック更新ビュー
struct QuickUpdateView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let bottle: Bottle

    @State private var remainingVolume: Double

    init(bottle: Bottle) {
        self.bottle = bottle
        _remainingVolume = State(initialValue: Double(bottle.remainingVolume))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // ボトル情報
                VStack(spacing: 8) {
                    Text(bottle.wrappedName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(bottle.wrappedDistillery)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // 残量表示
                VStack(spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(remainingVolume))")
                            .font(.system(size: 48, weight: .bold))
                        Text("ml")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }

                    Text("\(Int(remainingVolume * 100 / Double(bottle.volume)))%")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                // スライダー
                VStack(alignment: .leading, spacing: 8) {
                    Text("残量を調整")
                        .font(.headline)

                    Slider(value: $remainingVolume, in: 0...Double(bottle.volume), step: 10)
                        .tint(.blue)

                    HStack {
                        Text("0ml")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(bottle.volume)ml")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                Spacer()

                // よく使う量のショートカット
                VStack(alignment: .leading, spacing: 12) {
                    Text("よく使う量")
                        .font(.headline)

                    HStack(spacing: 12) {
                        quickUpdateButton(amount: -30, label: "-30ml")
                        quickUpdateButton(amount: -50, label: "-50ml")
                        quickUpdateButton(amount: -100, label: "-100ml")
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("残量更新")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRemainingVolume()
                    }
                }
            }
        }
    }

    private func quickUpdateButton(amount: Int, label: String) -> some View {
        Button {
            let newVolume = remainingVolume + Double(amount)
            remainingVolume = max(0, min(Double(bottle.volume), newVolume))
        } label: {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
        }
    }

    private func saveRemainingVolume() {
        withAnimation {
            let newRemaining = Int32(remainingVolume)

            // 未開栓で残量が減った場合は開栓日を設定
            if bottle.openedDate == nil && remainingVolume < Double(bottle.volume) {
                bottle.openedDate = Date()
            }

            do {
                try DrinkingLogService.shared.updateRemainingVolume(
                    bottle: bottle,
                    newRemaining: newRemaining,
                    context: viewContext
                )

                // 通知を再スケジュール
                Task {
                    await DrinkingLogService.shared.rescheduleAllNotifications(context: viewContext)
                }

                dismiss()
            } catch {
                let nsError = error as NSError
                print("⚠️ Failed to update remaining volume: \(nsError), \(nsError.userInfo)")
                dismiss()
            }
        }
    }
}

#Preview {
    BottleListView()
        .environment(\.managedObjectContext, CoreDataManager.preview.container.viewContext)
}