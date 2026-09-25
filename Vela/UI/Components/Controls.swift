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

/// Circular icon button. `filled` uses the Control fill; transport skip
/// buttons are transparent.
struct RoundIconButton: View {
    let icon: VelaIcon
    let diameter: CGFloat
    var iconSize: CGFloat
    var filled = true
    var foreground: Color?
    let label: String
    let action: () -> Void
    @Environment(\.palette) private var palette

    init(
        _ icon: VelaIcon, diameter: CGFloat, iconSize: CGFloat, filled: Bool = true,
        foreground: Color? = nil, label: String, action: @escaping () -> Void
    ) {
        self.icon = icon
        self.diameter = diameter
        self.iconSize = iconSize
        self.filled = filled
        self.foreground = foreground
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Icon(icon, size: iconSize)
                .foregroundStyle(foreground ?? palette.text)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(filled ? palette.fill : .clear))
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
    @Binding var selection: Value
    var accessibilityLabel: String
    var labelWeight: (Value) -> Font.Weight = { _ in .semibold }
    var leading: ((Value) -> AnyView)?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    HStack(spacing: 8) {
                        leading?(option.value)
                        Text(option.label)
                            .font(.system(size: 15, weight: labelWeight(option.value)))
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
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.fill))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// 51 × 31 switch in the design's monochrome style.
struct VelaSwitch: View {
    @Binding var isOn: Bool
    let label: String
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
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
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
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
    let icon: VelaIcon
    let label: String
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Icon(icon, size: 20)
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
                .foregroundStyle(palette.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.text))
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}

/// Page header: close chevron, tracked title, optional compact speed.
struct PageHeader: View {
    let title: String
    var backIcon: VelaIcon = .chevronDown
    var backLabel = "Back to dashboard"
    var speed: (value: Int?, unit: String)?
    let onBack: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                CircleNavButton(icon: backIcon, label: backLabel, action: onBack)
                Spacer(minLength: 0)
            }
            .frame(width: 88)
            TrackedLabel(text: title)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Spacer(minLength: 0)
                if let speed {
                    Text(speed.value.map(String.init) ?? "–")
                        .font(.system(size: 20, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.text)
                    Text(speed.unit)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(11 * 0.12)
                        .foregroundStyle(palette.text2)
                }
            }
            .frame(width: 88)
            .accessibilityElement(children: .combine)
        }
        .frame(height: 44)
    }
}
