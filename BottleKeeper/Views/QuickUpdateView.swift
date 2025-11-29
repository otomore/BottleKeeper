import SwiftUI

/// ボトルの残量をクイック更新するビュー
///
/// スライダーとショートカットボタンで残量を調整し、
/// 飲用ログを自動記録します。
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
