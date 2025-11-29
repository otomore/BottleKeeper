import SwiftUI
import CoreData

struct RemainingVolumeUpdateView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let bottle: Bottle
    @State private var remainingVolume: Double
    @State private var consumedVolume: String = ""

    init(bottle: Bottle) {
        self.bottle = bottle
        self._remainingVolume = State(initialValue: Double(bottle.remainingVolume))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(bottle.wrappedName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("現在の残量: \(bottle.remainingVolume)ml / \(bottle.volume)ml")
                        .foregroundColor(.secondary)

                    ProgressView(value: Double(bottle.remainingVolume), total: Double(bottle.volume))
                        .progressViewStyle(LinearProgressViewStyle(tint: progressColor(for: Double(bottle.remainingVolume) / Double(bottle.volume) * 100)))
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 16) {
                    Text("残量を更新")
                        .font(.headline)

                    VStack(spacing: 12) {
                        HStack {
                            Text("スライダーで調整")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        HStack {
                            Text("0ml")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Slider(value: $remainingVolume, in: 0...Double(bottle.volume), step: 10)
                                .accentColor(progressColor(for: remainingVolume / Double(bottle.volume) * 100))

                            Text("\(bottle.volume)ml")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("残量: \(Int(remainingVolume))ml (\(remainingVolume / Double(bottle.volume) * 100, specifier: "%.0f")%)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Divider()

                    VStack(spacing: 12) {
                        HStack {
                            Text("消費量を入力")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        HStack {
                            TextField("消費したml数を入力", text: $consumedVolume)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            Button("適用") {
                                if let consumed = Double(consumedVolume) {
                                    let newRemaining = max(0, Double(bottle.remainingVolume) - consumed)
                                    remainingVolume = newRemaining
                                    consumedVolume = ""
                                }
                            }
                            .disabled(consumedVolume.isEmpty)
                        }
                    }

                    // クイックアクションボタン
                    VStack(spacing: 8) {
                        HStack {
                            Text("クイックアクション")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        HStack(spacing: 12) {
                            QuickActionButton(title: "-30ml", action: { adjustVolume(-30) })
                            QuickActionButton(title: "-50ml", action: { adjustVolume(-50) })
                            QuickActionButton(title: "-100ml", action: { adjustVolume(-100) })
                            Spacer()
                        }
                    }
                }

                Spacer()
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
                    .disabled(remainingVolume == Double(bottle.remainingVolume))
                }
            }
        }
    }

    private func adjustVolume(_ amount: Double) {
        remainingVolume = max(0, min(Double(bottle.volume), remainingVolume + amount))
    }

    private func progressColor(for percentage: Double) -> Color {
        switch percentage {
        case 50...100:
            return .green
        case 20..<50:
            return .orange
        default:
            return .red
        }
    }

    private func saveRemainingVolume() {
        withAnimation {
            let newRemaining = Int32(remainingVolume)

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

struct QuickActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(6)
        }
    }
}

#Preview {
    RemainingVolumeUpdateView(bottle: {
        let context = CoreDataManager.preview.container.viewContext
        let bottle = Bottle(context: context)
        bottle.id = UUID()
        bottle.name = "山崎 12年"
        bottle.volume = 700
        bottle.remainingVolume = 400
        return bottle
    }())
    .environment(\.managedObjectContext, CoreDataManager.preview.container.viewContext)
}