import SwiftUI
import CoreData

struct BottleListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var motionManager = MotionManager()
    @StateObject private var viewModel = BottleListViewModel()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bottle.updatedAt, ascending: false)],
        animation: .default)
    private var bottles: FetchedResults<Bottle>

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                GeometryReader { geometry in
                    Group {
                        if !viewModel.hasBottles {
                            emptyStateView
                        } else {
                            bottleListContent(geometry: geometry)
                                .searchable(text: $viewModel.searchText, prompt: "銘柄名や蒸留所で検索")
                        }
                    }
                }

                // フローティングボタン（ランダム選択）
                if viewModel.hasBottles {
                    randomPickerButton
                }
            }
            .navigationTitle("コレクション")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showAddBottle()
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                if viewModel.hasBottles {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddBottle) {
                BottleFormView(bottle: nil)
            }
            .sheet(isPresented: $viewModel.showingQuickUpdate) {
                if let bottle = viewModel.selectedBottle {
                    QuickUpdateView(bottle: bottle)
                }
            }
            .sheet(isPresented: $viewModel.showingBottleDetail) {
                if let bottle = viewModel.selectedBottle {
                    NavigationStack {
                        BottleDetailView(bottle: bottle)
                    }
                }
            }
            .alert("今日のおすすめボトル", isPresented: $viewModel.showingRandomPicker) {
                Button("詳細を見る") {
                    viewModel.navigateToRandomBottleDetail()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                if let bottle = viewModel.randomBottle {
                    Text("今日は「\(bottle.wrappedName)」を楽しんでみませんか？\n蒸留所: \(bottle.wrappedDistillery)")
                }
            }
            .background {
                NavigationLink(
                    destination: viewModel.randomBottle.map { BottleDetailView(bottle: $0) },
                    isActive: $viewModel.navigateToRandomBottle
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .onAppear {
                viewModel.updateBottles(Array(bottles))
            }
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.updateFilteredBottles()
            }
            .onChange(of: bottles.count) { _, _ in
                viewModel.updateBottles(Array(bottles))
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
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
                viewModel.showAddBottle()
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
    }

    // MARK: - Random Picker Button

    private var randomPickerButton: some View {
        Button {
            viewModel.pickRandomBottle()
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

    // MARK: - Bottle List Content

    @ViewBuilder
    private func bottleListContent(geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let columns = viewModel.gridColumns(for: width)

        if columns > 1 {
            // iPad: グリッドレイアウト
            gridLayout(columns: columns)
        } else {
            // iPhone: リストレイアウト
            listLayout
        }
    }

    private func gridLayout(columns: Int) -> some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns), spacing: 16) {
                ForEach(viewModel.filteredBottles, id: \.id) { bottle in
                    Button {
                        viewModel.showBottleDetail(for: bottle)
                    } label: {
                        BottleRowView(bottle: bottle, motionManager: motionManager)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        contextMenuItems(for: bottle)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    private var listLayout: some View {
        List {
            ForEach(viewModel.filteredBottles, id: \.id) { bottle in
                Button {
                    viewModel.showBottleDetail(for: bottle)
                } label: {
                    BottleRowView(bottle: bottle, motionManager: motionManager)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .onLongPressGesture {
                    viewModel.showQuickUpdate(for: bottle)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        withAnimation {
                            viewModel.consumeOneShot(bottle, context: viewContext)
                        }
                    } label: {
                        Label("1ショット", systemImage: "drop.fill")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation {
                            viewModel.deleteBottle(bottle, context: viewContext)
                        }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                withAnimation {
                    viewModel.deleteBottles(at: offsets, context: viewContext)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for bottle: Bottle) -> some View {
        Button {
            viewModel.showQuickUpdate(for: bottle)
        } label: {
            Label("残量更新", systemImage: "drop.fill")
        }

        Button {
            withAnimation {
                viewModel.consumeOneShot(bottle, context: viewContext)
            }
        } label: {
            Label("1ショット消費", systemImage: "minus.circle")
        }

        Button(role: .destructive) {
            withAnimation {
                viewModel.deleteBottle(bottle, context: viewContext)
            }
        } label: {
            Label("削除", systemImage: "trash")
        }
    }
}

#Preview {
    BottleListView()
        .environment(\.managedObjectContext, CoreDataManager.preview.container.viewContext)
}
