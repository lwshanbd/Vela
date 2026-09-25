import SwiftUI

/// Color tokens from the Vela design system. Dark and light are drawn
/// separately, never derived from each other, and each has a "soft" ground
/// variant (Graphite in dark, Paper in light) chosen in Speed display settings.
struct Palette: Equatable {
    var bg: Color
    var text: Color
    var text2: Color
    var text3: Color
    var line: Color
    var fill: Color
    /// Inactive switch track, off fan bars.
    var fill2: Color
    /// Selected segment in a segmented control.
    var seg: Color
    /// Album artwork well.
    var art: Color
    var warn: Color
    var danger: Color
    /// Speed numeral weights: regular, bold.
    var speedWeights: (regular: Font.Weight, bold: Font.Weight)
    var isDark: Bool

    static func == (lhs: Palette, rhs: Palette) -> Bool {
        lhs.bg == rhs.bg && lhs.text == rhs.text && lhs.isDark == rhs.isDark
    }

    static func make(dark: Bool, ground: SpeedGround) -> Palette {
        switch (dark, ground) {
        case (false, .pure):
            Palette(
                bg: Color(hex: 0xFFFFFF), text: Color(hex: 0x0A0A0B), text2: Color(hex: 0x55554F),
                text3: Color(hex: 0xB9B9B3), line: Color(hex: 0xE4E4E0), fill: Color(hex: 0xEDEDEA),
                fill2: Color(hex: 0xD6D6D2), seg: Color(hex: 0xFFFFFF), art: Color(hex: 0xF3F3F0),
                warn: Color(hex: 0x9A5200), danger: Color(hex: 0xC42A1E),
                speedWeights: (.medium, .bold), isDark: false
            )
        case (false, .soft):
            Palette(
                bg: Color(hex: 0xF4F3EF), text: Color(hex: 0x0A0A0B), text2: Color(hex: 0x54534D),
                text3: Color(hex: 0xB3B2AB), line: Color(hex: 0xDEDDD7), fill: Color(hex: 0xE7E6E0),
                fill2: Color(hex: 0xD6D6D2), seg: Color(hex: 0xFFFFFF), art: Color(hex: 0xECEBE6),
                warn: Color(hex: 0x9A5200), danger: Color(hex: 0xC42A1E),
                speedWeights: (.medium, .bold), isDark: false
            )
        case (true, .pure):
            Palette(
                bg: Color(hex: 0x000000), text: Color(hex: 0xF2F2EE), text2: Color(hex: 0x9C9C97),
                text3: Color(hex: 0x4A4A48), line: Color(hex: 0x232322), fill: Color(hex: 0x161616),
                fill2: Color(hex: 0x2E2E2D), seg: Color(hex: 0x343433), art: Color(hex: 0x111111),
                warn: Color(hex: 0xF0A83A), danger: Color(hex: 0xFF6A5E),
                speedWeights: (.regular, .semibold), isDark: true
            )
        case (true, .soft):
            Palette(
                bg: Color(hex: 0x121315), text: Color(hex: 0xF2F2EE), text2: Color(hex: 0x9EA0A4),
                text3: Color(hex: 0x4E5055), line: Color(hex: 0x26282B), fill: Color(hex: 0x1D1F22),
                fill2: Color(hex: 0x2E3034), seg: Color(hex: 0x3A3C40), art: Color(hex: 0x1A1B1E),
                warn: Color(hex: 0xF0A83A), danger: Color(hex: 0xFF6A5E),
                speedWeights: (.regular, .semibold), isDark: true
            )
        }
    }
}

extension SpeedTint {
    /// Speed and gear color. Controls always stay neutral.
    func color(dark: Bool) -> Color {
        let pair: (UInt32, UInt32) = switch self {
        case .pure: (0xF2F2EE, 0x0A0A0B)
        case .graphite: (0xBFC1C4, 0x45474B)
        case .sand: (0xE6D3B0, 0x7A5F2E)
        case .sage: (0xA9D6B6, 0x2A6B47)
        case .ice: (0xA6D0F2, 0x155C9A)
        case .lilac: (0xC9BCF4, 0x5A43B0)
        }
        return Color(hex: dark ? pair.0 : pair.1)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.make(dark: true, ground: .pure)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
