import SwiftUI

/// コレクション内のボトル行を表示するビュー
///
/// ボトルの残量をアニメーション付きで視覚的に表示し、
/// 銘柄名、蒸留所、開栓状態、評価などの情報を表示します。
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
