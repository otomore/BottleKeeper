import SwiftUI
import CoreData

struct WishlistView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \WishlistItem.priority, ascending: false),
            NSSortDescriptor(keyPath: \WishlistItem.createdAt, ascending: false)
        ],
        animation: .default)
    private var wishlistItems: FetchedResults<WishlistItem>

    @State private var showingAddItem = false
    @State private var searchText = ""
    @State private var itemToMoveToCollection: WishlistItem?
    @State private var showingMoveConfirmation = false
    @State private var showingBottleForm = false
    @State private var wishlistItemForBottle: WishlistItem?

    var filteredItems: [WishlistItem] {
        wishlistItems.filtered(by: searchText)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                Group {
                    if wishlistItems.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "star.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text("ウィッシュリストが空です")
                                .font(.headline)
                                .foregroundColor(.gray)

                            Text("欲しいウイスキーを追加して管理しましょう")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button {
                                showingAddItem = true
                            } label: {
                                Label("追加する", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        wishlistContent(geometry: geometry)
                            .searchable(text: $searchText, prompt: "銘柄名や蒸留所で検索")
                    }
                }
            }
            .navigationTitle("ウィッシュリスト")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                if !wishlistItems.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                WishlistFormView(wishlistItem: nil)
            }
            .sheet(isPresented: $showingBottleForm) {
                if let wishlistItem = wishlistItemForBottle {
                    WishlistToBottleFormView(wishlistItem: wishlistItem, onComplete: {
                        // ウィッシュリストアイテムを削除
                        viewContext.delete(wishlistItem)
                        do {
                            try viewContext.save()
                        } catch {
                            print("⚠️ Failed to delete wishlist item: \(error)")
                        }
                        showingBottleForm = false
                    })
                }
            }
            .alert("コレクションに追加", isPresented: $showingMoveConfirmation) {
                Button("キャンセル", role: .cancel) {}
                Button("追加") {
                    if let item = itemToMoveToCollection {
                        moveToCollection(item)
                    }
                }
            } message: {
                if let item = itemToMoveToCollection {
                    Text("\(item.wrappedName)をコレクションに追加しますか？")
                }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredItems[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("⚠️ Failed to delete wishlist items: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    @ViewBuilder
    private func wishlistContent(geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let columns = gridColumns(for: width)

        if columns > 1 {
            // iPad: グリッドレイアウト
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns), spacing: 16) {
                    ForEach(filteredItems, id: \.id) { item in
                        WishlistRowView(item: item, onMoveToCollection: {
                            itemToMoveToCollection = item
                            showingMoveConfirmation = true
                        })
                        .contextMenu {
                            Button {
                                itemToMoveToCollection = item
                                showingMoveConfirmation = true
                            } label: {
                                Label("コレクションに追加", systemImage: "plus.circle")
                            }

                            Button(role: .destructive) {
                                viewContext.delete(item)
                                do {
                                    try viewContext.save()
                                } catch {
                                    print("⚠️ Failed to delete item: \(error)")
                                }
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        } else {
            // iPhone: リストレイアウト
            List {
                ForEach(filteredItems, id: \.id) { item in
                    WishlistRowView(item: item, onMoveToCollection: {
                        itemToMoveToCollection = item
                        showingMoveConfirmation = true
                    })
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: deleteItems)
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

    private func moveToCollection(_ item: WishlistItem) {
        wishlistItemForBottle = item
        showingBottleForm = true
    }
}

struct WishlistRowView: View {
    let item: WishlistItem
    let onMoveToCollection: () -> Void

    @State private var showingEditForm = false

    var body: some View {
        HStack(spacing: 12) {
            // 優先度インジケーター
            RoundedRectangle(cornerRadius: 4)
                .fill(priorityColor(for: item.priority))
                .frame(width: 4, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.wrappedName)
                    .font(.headline)

                Text(item.wrappedDistillery)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    // 優先度
                    Label(item.priorityLevel, systemImage: "flag.fill")
                        .font(.caption)
                        .foregroundColor(priorityColor(for: item.priority))

                    // 価格情報
                    if let targetPrice = item.targetPrice {
                        Label("¥\(targetPrice)", systemImage: "yensign.circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            // アクションボタン
            Menu {
                Button {
                    showingEditForm = true
                } label: {
                    Label("編集", systemImage: "pencil")
                }

                Button {
                    onMoveToCollection()
                } label: {
                    Label("コレクションに追加", systemImage: "plus.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.blue)
                    .imageScale(.large)
            }
        }
        .padding()
        .subtleGlassEffect(tint: .blue)
        .sheet(isPresented: $showingEditForm) {
            WishlistFormView(wishlistItem: item)
        }
    }

    private func priorityColor(for priority: Int16) -> Color {
        switch priority {
        case 5:
            return .red
        case 4:
            return .orange
        case 3:
            return .yellow
        case 2:
            return .green
        case 1:
            return .blue
        default:
            return .gray
        }
    }
}

// ウィッシュリストからボトルへの変換フォーム
struct WishlistToBottleFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let wishlistItem: WishlistItem
    let onComplete: () -> Void

    @State private var name: String
    @State private var distillery: String
    @State private var region = ""
    @State private var type = ""
    @State private var abv = 40.0
    @State private var volume: Int32 = 700
    @State private var vintage: Int32 = 0
    @State private var purchaseDate = Date()
    @State private var purchasePrice: String
    @State private var shop = ""
    @State private var rating: Int16 = 0
    @State private var notes: String
    @FocusState private var focusedField: Field?

    enum Field {
        case purchasePrice
    }

    init(wishlistItem: WishlistItem, onComplete: @escaping () -> Void) {
        self.wishlistItem = wishlistItem
        self.onComplete = onComplete
        _name = State(initialValue: wishlistItem.wrappedName)
        _distillery = State(initialValue: wishlistItem.wrappedDistillery)
        _notes = State(initialValue: wishlistItem.wrappedNotes)

        // 予算または目標価格を購入価格の初期値に設定
        if let budget = wishlistItem.budget {
            _purchasePrice = State(initialValue: budget.stringValue)
        } else if let targetPrice = wishlistItem.targetPrice {
            _purchasePrice = State(initialValue: targetPrice.stringValue)
        } else {
            _purchasePrice = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("銘柄名", text: $name)
                    TextField("蒸留所（任意）", text: $distillery)
                    TextField("地域", text: $region)
                    TextField("タイプ", text: $type)

                    HStack {
                        Text("アルコール度数")
                        Spacer()
                        TextField("40.0", value: $abv, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        Text("%")
                    }

                    HStack {
                        Text("容量")
                        Spacer()
                        TextField("700", value: $volume, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        Text("ml")
                    }

                    HStack {
                        Text("年代")
                        Spacer()
                        TextField("任意", value: $vintage, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        Text("年")
                    }
                }

                Section("購入情報") {
                    DatePicker("購入日", selection: $purchaseDate, displayedComponents: .date)

                    HStack {
                        Text("購入価格")
                        Spacer()
                        TextField("任意", text: $purchasePrice)
                            .focused($focusedField, equals: .purchasePrice)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                        Text("円")
                    }

                    TextField("購入店舗（任意）", text: $shop)
                }

                Section("評価・ノート") {
                    HStack {
                        Text("評価")
                        Spacer()
                        StarRatingView(rating: $rating)
                    }

                    TextField("テイスティングノート（任意）", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("コレクションに追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        saveBottle()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .onAppear {
            // 購入価格フィールドにフォーカス
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .purchasePrice
            }
        }
    }

    private func saveBottle() {
        withAnimation {
            let bottle = Bottle(context: viewContext)
            bottle.id = UUID()
            bottle.name = name
            bottle.distillery = distillery.isEmpty ? nil : distillery
            bottle.region = region.isEmpty ? nil : region
            bottle.type = type.isEmpty ? nil : type
            bottle.abv = abv
            bottle.volume = volume
            bottle.vintage = vintage
            bottle.purchaseDate = purchaseDate

            if !purchasePrice.isEmpty, let price = Decimal(string: purchasePrice) {
                bottle.purchasePrice = NSDecimalNumber(decimal: price)
            }

            bottle.shop = shop.isEmpty ? nil : shop
            bottle.rating = rating
            bottle.notes = notes.isEmpty ? nil : notes
            bottle.createdAt = Date()
            bottle.updatedAt = Date()
            bottle.remainingVolume = volume // 新品として登録

            do {
                try viewContext.save()
                onComplete()
                dismiss()
            } catch {
                let nsError = error as NSError
                print("⚠️ Failed to save bottle: \(nsError), \(nsError.userInfo)")
                dismiss()
            }
        }
    }
}

#Preview {
    WishlistView()
        .environment(\.managedObjectContext, CoreDataManager.preview.container.viewContext)
}