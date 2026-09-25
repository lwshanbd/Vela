import SwiftUI

/// Icons from the design, drawn from its own SVG path data on a 24-unit grid.
enum VelaGlyph: Hashable {
    case sliders, minus, plus, previous, next, play, pause, playPause
    case chevronDown, chevronLeft, chevronRight, close, check, power, key
    case note, speaker, bolt, range, car, sun, compass, tire, door, update
    case lock, unlock, flag, frontTrunk, rearTrunk, window, eye, sunroof, garage
    case refresh, heat, cool, phone, radio, navArrow, errorCircle, grip

    fileprivate var data: String {
        switch self {
        case .sliders: "M4 7h10M18 7h2M4 17h4M12 17h8M14 7a2 2 0 1 0 4 0a2 2 0 1 0 -4 0M8 17a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"
        case .minus: "M5 12h14"
        case .plus: "M12 5v14M5 12h14"
        case .previous: "M6 6h2.2v12H6zM19.5 6.3v11.4L9.6 12z"
        case .next: "M15.8 6H18v12h-2.2zM4.5 6.3v11.4L14.4 12z"
        case .play: "M8 5.2v13.6L19 12z"
        case .pause: "M7 5h3.4v14H7zM13.6 5H17v14h-3.4z"
        // Play triangle beside pause bars, for cars that don't say whether they play.
        case .playPause: "M3 6v12l9-6zM14 6h2.6v12H14zM18.4 6H21v12h-2.6z"
        case .chevronDown: "M6 9l6 6 6-6"
        case .chevronLeft: "M15 6l-6 6 6 6"
        case .chevronRight: "M9 6l6 6-6 6"
        case .close: "M6 6l12 12M18 6L6 18"
        case .check: "M5 12.5l4.5 4.5L19 7.5"
        case .power: "M12 3.5v7.5M6.6 6.8a7.5 7.5 0 1 0 10.8 0"
        case .key: "M3.5 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0M11.5 12H21M18 12v3.5M21 12v2.5"
        case .note: "M9 18V6l10-2v12M4 18a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0M14 16a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0"
        case .speaker: "M4 9.5h3.5L12 6v12l-4.5-3.5H4zM16 9a4 4 0 0 1 0 6"
        case .bolt: "M13 3L5 14h6l-1 7 8-11h-6z"
        case .range: "M8 20L10.5 4M16 20L13.5 4M12 7v2M12 12v2M12 17v2"
        case .car: "M4 16v-3l2-5h12l2 5v3zM4 13h16M7 16v2M17 16v2"
        case .sun: "M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"
        case .compass: "M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0M15.5 8.5l-2 5-5 2 2-5z"
        case .tire: "M4 12a8 8 0 1 0 16 0a8 8 0 1 0 -16 0M9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0"
        case .door: "M7 7a4 4 0 0 1 4-4h2a4 4 0 0 1 4 4v10a4 4 0 0 1-4 4h-2a4 4 0 0 1-4-4zM7 12L3 14.5"
        case .update: "M12 4v11M7 10l5 5 5-5M5 20h14"
        case .lock: "M5 13a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2zM8 11V8a4 4 0 0 1 8 0v3"
        case .unlock: "M5 13a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2zM8 11V8a4 4 0 0 1 7.5-2"
        case .flag: "M5 21V4h11l-2 4 2 4H5"
        case .frontTrunk: "M8 7a4 4 0 0 1 8 0v12a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2zM9 2.5h6"
        case .rearTrunk: "M8 5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v12a4 4 0 0 1-8 0zM9 21.5h6"
        case .window: "M4 6h16v12H4zM4 12h16"
        case .eye: "M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12zM9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0"
        case .sunroof: "M5 5h14v14H5zM8 8h8v5H8z"
        case .garage: "M3 11l9-7 9 7v9H3zM7 20v-6h10v6"
        case .refresh: "M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"
        case .heat: "M8 20c-2-3 2-5 0-8s2-5 0-8M12 20c-2-3 2-5 0-8s2-5 0-8M16 20c-2-3 2-5 0-8s2-5 0-8"
        case .cool: "M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9"
        case .phone: "M9.5 2.5h5A2.5 2.5 0 0 1 17 5v14a2.5 2.5 0 0 1-2.5 2.5h-5A2.5 2.5 0 0 1 7 19V5a2.5 2.5 0 0 1 2.5-2.5zM11 18.5h2"
        case .radio: "M5 8h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2zM7 8l10-5M13 14a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0"
        case .navArrow: "M12 3l7 17-7-4-7 4z"
        case .errorCircle: "M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0M12 7.5v5.5M12 16.5v.01"
        case .grip: "M5 9h14M5 15h14"
        }
    }

    fileprivate var isFilled: Bool {
        switch self {
        case .previous, .next, .play, .pause, .playPause, .navArrow: true
        default: false
        }
    }

    fileprivate var lineWidth: CGFloat {
        switch self {
        case .sliders, .key: 1.7
        case .chevronDown, .chevronLeft, .chevronRight, .check, .power, .grip: 2
        case .close, .errorCircle: 2.2
        default: 1.8
        }
    }

    @MainActor private static var cache: [VelaGlyph: Path] = [:]

    @MainActor fileprivate var path: Path {
        if let cached = Self.cache[self] { return cached }
        let parsed = SVGPath.parse(data)
        Self.cache[self] = parsed
        return parsed
    }
}

struct Icon: View {
    let glyph: VelaGlyph
    var size: CGFloat
    var lineWidth: CGFloat?

    init(_ glyph: VelaGlyph, size: CGFloat = 24, lineWidth: CGFloat? = nil) {
        self.glyph = glyph
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        let shape = SVGShape(path: glyph.path)
        Group {
            if glyph.isFilled {
                shape.fill()
            } else {
                shape.stroke(style: StrokeStyle(
                    lineWidth: (lineWidth ?? glyph.lineWidth) * size / 24,
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

/// Four signal bars; bars up to `level` are drawn in full color.
struct SignalBars: View {
    let level: Int
    var on: Color
    var off: Color

    var body: some View {
        Canvas { context, canvas in
            let u = canvas.width / 24
            let bars: [(CGFloat, CGFloat, CGFloat)] = [(3, 15, 5), (8.5, 11, 9), (14, 7, 13), (19.5, 3, 17)]
            for (index, bar) in bars.enumerated() {
                let rect = CGRect(x: bar.0 * u, y: bar.1 * u, width: 3 * u, height: bar.2 * u)
                context.fill(Path(roundedRect: rect, cornerRadius: u), with: .color(index < level ? on : off))
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
            Circle().stroke(palette.line, lineWidth: 1.8)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(palette.text, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
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
