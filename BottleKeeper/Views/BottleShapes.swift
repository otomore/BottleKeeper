import SwiftUI

/// ボトル形状のカスタムビュー
///
/// ボトルの輪郭と液体の残量を視覚的に表示するコンポーネント。
/// デバイスの傾きに応じて液体が動くアニメーションを提供します。
struct BottleShapeView: View {
    /// 残量の割合（0.0 ~ 1.0）
    let remainingPercentage: Double
    /// モーションマネージャー（デバイスの傾き検出用）
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
                    .clipShape(BottleOutlineShape())
                }
                .onChange(of: timeline.date) { _ in
                    wavePhase += 0.05
                }
            }
        }
    }
}

/// ボトルの輪郭を描画するShape
///
/// ウイスキーボトルの形状を再現したカスタムShape。
/// 首、胴体、底の3つのパーツで構成されています。
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

/// 波動を持つ液体を描画するShape
///
/// デバイスの傾きに応じて液面が傾き、波のアニメーションを表示します。
struct LiquidWaveShape: Shape {
    /// 液体の高さ（0.0 ~ 1.0）
    var liquidHeight: Double
    /// 傾きによるオフセット
    var tiltOffset: Double
    /// 波の位相
    var wavePhase: Double
    /// 波の振幅
    var waveAmplitude: Double

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
        let waveFrequency = 2.0 * .pi / width
        let segments = 50

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

/// AnimatableDataを4つのDoubleに拡張
///
/// SwiftUIのアニメーションで4つの値を同時にアニメーションするための構造体。
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
