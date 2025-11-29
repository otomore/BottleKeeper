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

#Preview {
    BottleListView()
        .environment(\.managedObjectContext, CoreDataManager.preview.container.viewContext)
}
