import SwiftUI

/// プレミアム機能の行を表示するビュー
///
/// アイコン、タイトル、説明、価格を表示し、
/// 購入ボタンとして機能します。
struct PremiumFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let price: String
    let isPurchased: Bool

    var body: some View {
        Button {
            // TODO: 実際の購入処理を実装
            print("購入ボタンタップ: \(title)")
        } label: {
            HStack(spacing: 12) {
                // アイコン
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconColor.opacity(0.15))
                    .cornerRadius(10)

                // 説明
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // 価格または購入済みバッジ
                if isPurchased {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                } else {
                    VStack(spacing: 2) {
                        Text(price)
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("購入")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.8, green: 0.5, blue: 0.2).opacity(0.3), lineWidth: 1)
                }
        }
        .disabled(isPurchased)
    }
}

/// CloudKit デバッグログを表示するビュー
///
/// CloudKit同期に関するログを表示し、
/// クリップボードへのコピーやクリア機能を提供します。
struct CloudKitDebugLogView: View {
    @ObservedObject private var coreDataManager = CoreDataManager.shared
    @State private var showingCopyConfirmation = false
    @State private var showingClearConfirmation = false

    var body: some View {
        List {
            Section {
                if coreDataManager.logs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "text.alignleft")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("ログがありません")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(coreDataManager.logs, id: \.self) { log in
                        Text(log)
                            .font(.caption)
                            .textSelection(.enabled)
                            .padding(.vertical, 4)
                    }
                }
            } header: {
                HStack {
                    Text("CloudKit同期ログ")
                    Spacer()
                    Text("\(coreDataManager.logs.count)件")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } footer: {
                Text("ログは最新100件まで保存されます。CloudKit同期に関するイベントとエラーが記録されます。")
                    .font(.caption2)
            }

            Section {
                Button {
                    UIPasteboard.general.string = coreDataManager.logs.joined(separator: "\n")
                    showingCopyConfirmation = true
                } label: {
                    Label("ログをコピー", systemImage: "doc.on.clipboard")
                }
                .disabled(coreDataManager.logs.isEmpty)

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("ログをクリア", systemImage: "trash")
                }
                .disabled(coreDataManager.logs.isEmpty)
            }
        }
        .navigationTitle("CloudKit デバッグ")
        .navigationBarTitleDisplayMode(.inline)
        .alert("コピー完了", isPresented: $showingCopyConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("ログをクリップボードにコピーしました")
        }
        .alert("ログをクリア", isPresented: $showingClearConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("クリア", role: .destructive) {
                coreDataManager.clearLogs()
            }
        } message: {
            Text("すべてのログを削除します。この操作は取り消せません。")
        }
    }
}
