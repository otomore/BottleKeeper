import SwiftUI

/// 消費トレンドの期間タイプ
enum ConsumptionPeriod {
    case monthly
    case yearly
}

/// 統計カードを表示するビュー
///
/// タイトル、値、アイコン、色を指定してカード形式で統計情報を表示します。
struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .subtleGlassEffect(tint: color)
    }
}

/// コストパフォーマンスの行を表示するビュー
///
/// ランキング順にボトルのml単価を表示します。
struct CostPerformanceRow: View {
    let index: Int
    let bottle: Bottle
    let pricePerMl: Decimal

    var body: some View {
        HStack {
            // ランキング番号
            Text("\(index + 1)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(rankingColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(bottle.wrappedName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(bottle.wrappedDistillery)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(NSDecimalNumber(decimal: pricePerMl).doubleValue, specifier: "%.1f")/ml")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)

                if let price = bottle.purchasePrice {
                    Text("総額: ¥\(Int(truncating: price))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .subtleGlassEffect(tint: .gray)
    }

    private var rankingColor: Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .orange
        default: return .blue
        }
    }
}
