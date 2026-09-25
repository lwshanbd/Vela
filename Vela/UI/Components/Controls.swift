import SwiftUI

/// Press state from the design: 80 ms scale to 0.96 plus a light haptic.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

/// Circular icon button. `fill` nil means transparent (transport skip).
struct RoundIconButton: View {
    let glyph: VelaGlyph
    let diameter: CGFloat
    let iconSize: CGFloat
    var fill: Color?
    var foreground: Color?
    let label: String
    let action: () -> Void
    @Environment(\.palette) private var palette

    init(
        _ glyph: VelaGlyph, diameter: CGFloat, iconSize: CGFloat, fill: Color?,
        foreground: Color? = nil, label: String, action: @escaping () -> Void
    ) {
        self.glyph = glyph
        self.diameter = diameter
        self.iconSize = iconSize
        self.fill = fill
        self.foreground = foreground
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Icon(glyph, size: iconSize)
                .foregroundStyle(foreground ?? palette.text)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(fill ?? .clear))
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

struct Hairline: View {
    var vertical = false
    @Environment(\.palette) private var palette
    var body: some View {
        Rectangle()
            .fill(palette.line)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}

/// Segmented control: 48 pt track, 3 pt inset, 14/11 pt radii.
struct Segmented<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    let selection: Value?
    var accessibilityLabel: String
    var height: CGFloat = 48
    var labelWeight: (Value) -> Font.Weight = { _ in .semibold }
    var leading: ((Value) -> AnyView)?
    let pick: (Value) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button {
                    pick(option.value)
                } label: {
                    HStack(spacing: 8) {
                        leading?(option.value)
                        Text(option.label)
                            .font(.system(size: 15, weight: labelWeight(option.value)))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selected ? palette.text : palette.text2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(selected ? palette.seg : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.fill))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// 51 × 31 switch in the design's monochrome style.
struct VelaSwitch: View {
    let isOn: Bool
    let label: String
    let toggle: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: toggle) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? palette.text : palette.fill2)
                Circle()
                    .fill(isOn ? palette.bg : Color.white)
                    .frame(width: 27, height: 27)
                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                    .padding(2)
            }
            .frame(width: 51, height: 31)
            .frame(width: 60, height: 44, alignment: .trailing)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? String(localized: "On") : String(localized: "Off"))
        .accessibilityAddTraits(.isToggle)
    }
}

/// Label on the left, switch on the right, hairline below.
struct SwitchRow: View {
    let title: String
    var subtitle: String?
    let isOn: Bool
    var height: CGFloat = 60
    let toggle: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 17)).foregroundStyle(palette.text)
                if let subtitle {
                    Text(subtitle).font(.system(size: 15)).foregroundStyle(palette.text2)
                }
            }
            Spacer(minLength: 0)
            VelaSwitch(isOn: isOn, label: title, toggle: toggle)
        }
        .frame(minHeight: height)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

/// Battery outline with a fill proportional to charge.
struct BatteryGlyph: View {
    let level: Int
    var width: CGFloat = 25
    var height: CGFloat = 13
    let color: Color

    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(color, lineWidth: 1.5)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(color)
                    .frame(width: (width - 6) * CGFloat(min(100, max(0, level))) / 100)
                    .padding(3)
            }
            .frame(width: width, height: height)
            UnevenRoundedRectangle(bottomTrailingRadius: 1, topTrailingRadius: 1)
                .fill(color)
                .frame(width: 2, height: 5)
        }
        .accessibilityHidden(true)
    }
}

/// Uppercase tracked label (NOW PLAYING, CLIMATE, section headers).
struct TrackedLabel: View {
    let text: String
    var size: CGFloat = 13
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold))
            .tracking(size * 0.12)
            .foregroundStyle(palette.text2)
    }
}

/// 44 pt circular back/close button used on pages and setup screens.
struct CircleNavButton: View {
    let glyph: VelaGlyph
    let label: String
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Icon(glyph, size: 20)
                .foregroundStyle(palette.text)
                .frame(width: 44, height: 44)
                .background(Circle().fill(palette.fill))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// 58 pt primary action (Get started, Continue, Open dashboard).
struct PrimaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? palette.bg : palette.text2)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(enabled ? palette.text : palette.fill))
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}

/// Rounded pill button, filled when selected (Max defrost, overheat temps).
struct PillButton: View {
    let title: String
    var selected = false
    var height: CGFloat = 44
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selected ? palette.bg : palette.text)
                .padding(.horizontal, 16)
                .frame(height: height)
                .background(Capsule().fill(selected ? palette.text : palette.fill))
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Page header: close chevron, tracked title, optional trailing content.
struct PageHeader<Trailing: View>: View {
    let title: String
    var backGlyph: VelaGlyph = .chevronDown
    var backLabel = String(localized: "Back to dashboard")
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                CircleNavButton(glyph: backGlyph, label: backLabel, action: onBack)
                Spacer(minLength: 0)
            }
            .frame(width: 88)
            TrackedLabel(text: title)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack {
                Spacer(minLength: 0)
                trailing()
            }
            .frame(width: 88)
        }
        .frame(height: 44)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, backGlyph: VelaGlyph = .chevronDown, backLabel: String = String(localized: "Back to dashboard"), onBack: @escaping () -> Void) {
        self.init(title: title, backGlyph: backGlyph, backLabel: backLabel, onBack: onBack) { EmptyView() }
    }
}

/// Compact speed readout for page headers while driving.
struct HeaderSpeed: View {
    let value: Int?
    let unit: String
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value.map(String.init) ?? "–")
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(palette.text)
            Text(unit)
                .font(.system(size: 11, weight: .semibold))
                .tracking(11 * 0.12)
                .foregroundStyle(palette.text2)
        }
        .accessibilityElement(children: .combine)
    }
}
