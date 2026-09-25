import SwiftUI

/// Icons drawn from the design's inline SVGs (24-unit viewBox), so strokes and
/// proportions match the mockups instead of approximating with SF Symbols.
enum VelaIcon {
    case sliders, minus, plus, previous, next, play, pause, playPause
    case chevronDown, chevronLeft, chevronRight, note, volumeDown, volumeUp
    case power, key, check

    fileprivate var isFilled: Bool {
        switch self {
        case .previous, .next, .play, .pause, .playPause: true
        default: false
        }
    }

    fileprivate var lineWidth: CGFloat {
        switch self {
        case .sliders: 1.7
        case .chevronDown, .chevronLeft, .chevronRight, .power, .check: 2
        case .note, .key: 1.6
        default: 1.8
        }
    }

    fileprivate func path(in u: CGFloat) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * u, y: y * u) }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: x * u, y: y * u, width: w * u, height: h * u)
        }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGRect {
            rect(cx - r, cy - r, 2 * r, 2 * r)
        }
        var path = Path()
        switch self {
        case .sliders:
            path.move(to: p(4, 7)); path.addLine(to: p(14, 7))
            path.move(to: p(18, 7)); path.addLine(to: p(20, 7))
            path.move(to: p(4, 17)); path.addLine(to: p(8, 17))
            path.move(to: p(12, 17)); path.addLine(to: p(20, 17))
            path.addEllipse(in: circle(16, 7, 2))
            path.addEllipse(in: circle(10, 17, 2))
        case .minus:
            path.move(to: p(5, 12)); path.addLine(to: p(19, 12))
        case .plus:
            path.move(to: p(12, 5)); path.addLine(to: p(12, 19))
            path.move(to: p(5, 12)); path.addLine(to: p(19, 12))
        case .previous:
            path.addRect(rect(6, 6, 2.2, 12))
            path.move(to: p(19.5, 6.3)); path.addLine(to: p(19.5, 17.7)); path.addLine(to: p(9.6, 12)); path.closeSubpath()
        case .next:
            path.addRect(rect(15.8, 6, 2.2, 12))
            path.move(to: p(4.5, 6.3)); path.addLine(to: p(4.5, 17.7)); path.addLine(to: p(14.4, 12)); path.closeSubpath()
        case .play:
            path.move(to: p(8, 5.2)); path.addLine(to: p(8, 18.8)); path.addLine(to: p(19, 12)); path.closeSubpath()
        case .pause:
            path.addRect(rect(7, 5, 3.4, 14))
            path.addRect(rect(13.6, 5, 3.4, 14))
        case .playPause:
            // Play triangle beside pause bars, for cars that don't report
            // whether they are playing.
            path.move(to: p(3, 6)); path.addLine(to: p(3, 18)); path.addLine(to: p(12, 12)); path.closeSubpath()
            path.addRect(rect(14, 6, 2.6, 12))
            path.addRect(rect(18.4, 6, 2.6, 12))
        case .chevronDown:
            path.move(to: p(6, 9)); path.addLine(to: p(12, 15)); path.addLine(to: p(18, 9))
        case .chevronLeft:
            path.move(to: p(15, 6)); path.addLine(to: p(9, 12)); path.addLine(to: p(15, 18))
        case .chevronRight:
            path.move(to: p(9, 6)); path.addLine(to: p(15, 12)); path.addLine(to: p(9, 18))
        case .note:
            path.move(to: p(9, 18)); path.addLine(to: p(9, 6)); path.addLine(to: p(19, 4)); path.addLine(to: p(19, 16))
            path.addEllipse(in: circle(6.5, 18, 2.5))
            path.addEllipse(in: circle(16.5, 16, 2.5))
        case .volumeDown, .volumeUp:
            path.move(to: p(4, 9.5)); path.addLine(to: p(7.5, 9.5)); path.addLine(to: p(12, 6))
            path.addLine(to: p(12, 18)); path.addLine(to: p(7.5, 14.5)); path.addLine(to: p(4, 14.5)); path.closeSubpath()
            path.move(to: p(16, 12)); path.addLine(to: p(20, 12))
            if self == .volumeUp {
                path.move(to: p(18, 10)); path.addLine(to: p(18, 14))
            }
        case .power:
            path.move(to: p(12, 3.5)); path.addLine(to: p(12, 11))
            // Arc from (6.6, 6.8) around to (17.4, 6.8), r 7.5, open at the top.
            let center = p(12, 12)
            path.move(to: p(6.6, 6.8))
            path.addArc(center: center, radius: 7.5 * u, startAngle: .degrees(-136), endAngle: .degrees(-44), clockwise: true)
        case .key:
            path.addEllipse(in: circle(7.5, 12, 4))
            path.move(to: p(11.5, 12)); path.addLine(to: p(21, 12))
            path.move(to: p(18, 12)); path.addLine(to: p(18, 15.5))
            path.move(to: p(21, 12)); path.addLine(to: p(21, 14.5))
        case .check:
            path.move(to: p(5, 12.5)); path.addLine(to: p(9.5, 17)); path.addLine(to: p(19, 7.5))
        }
        return path
    }
}

struct Icon: View {
    let icon: VelaIcon
    var size: CGFloat = 24
    var lineWidth: CGFloat?

    init(_ icon: VelaIcon, size: CGFloat = 24, lineWidth: CGFloat? = nil) {
        self.icon = icon
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        let unit = size / 24
        let path = icon.path(in: unit)
        Group {
            if icon.isFilled {
                path.fill()
            } else {
                path.stroke(style: StrokeStyle(
                    lineWidth: (lineWidth ?? icon.lineWidth) * unit,
                    lineCap: .round,
                    lineJoin: .round
                ))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Vela mark: a horizon line with the sun resting above it.
struct VelaLogo: View {
    var size: CGFloat = 72
    var body: some View {
        Canvas { context, canvas in
            let u = canvas.width / 64
            var line = Path()
            line.move(to: CGPoint(x: 8 * u, y: 42 * u))
            line.addLine(to: CGPoint(x: 56 * u, y: 42 * u))
            context.stroke(line, with: .foreground, style: StrokeStyle(lineWidth: 3 * u, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: 25 * u, y: 20 * u, width: 14 * u, height: 14 * u)), with: .foreground)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Four signal bars; `level` 1–4 are drawn in full color, the rest muted.
struct SignalBars: View {
    let level: Int
    @Environment(\.palette) private var palette

    var body: some View {
        Canvas { context, canvas in
            let u = canvas.width / 24
            let bars: [(CGFloat, CGFloat, CGFloat)] = [(3, 15, 5), (8.5, 11, 9), (14, 7, 13), (19.5, 3, 17)]
            for (index, bar) in bars.enumerated() {
                let rect = CGRect(x: bar.0 * u, y: bar.1 * u, width: 3 * u, height: bar.2 * u)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: u),
                    with: .color(index < level ? palette.text : palette.fill2)
                )
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

/// Small spinner used in "Searching nearby" / "Waiting for your car".
struct ArcSpinner: View {
    @Environment(\.palette) private var palette
    @State private var spinning = false

    var body: some View {
        ZStack {
            Circle().stroke(palette.line, lineWidth: 2.4 * 0.75)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(palette.text, style: StrokeStyle(lineWidth: 2.4 * 0.75, lineCap: .round))
                .rotationEffect(.degrees(spinning ? 360 : 0))
        }
        .frame(width: 13.5, height: 13.5)
        .frame(width: 18, height: 18)
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                spinning = true
            }
        }
        .accessibilityHidden(true)
    }
}
