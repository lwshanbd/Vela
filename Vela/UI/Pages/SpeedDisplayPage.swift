import SwiftUI

/// Speed display personalization: tint, ground and numeral weight, with a
/// preview of the instrument. The preview shows the car's live speed when
/// connected, and 0 otherwise.
struct SpeedDisplayPage: View {
    let model: AppModel
    let layout: PageLayout
    let onBack: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        let settings = model.settings
        VStack(spacing: 0) {
            PageHeader(title: "SPEED DISPLAY", backIcon: .chevronLeft, backLabel: "Back to settings", onBack: onBack)
            if layout.landscape {
                HStack(spacing: 40) {
                    preview(height: layout.contentHeight - 44)
                        .frame(maxWidth: .infinity)
                    ScrollView(.vertical) { controls(settings) }
                        .scrollBounceBehavior(.basedOnSize)
                        .frame(maxWidth: .infinity)
                }
            } else {
                preview(height: min(300, layout.contentHeight * 0.38))
                    .padding(.top, 12)
                Hairline()
                ScrollView(.vertical) { controls(settings) }
                    .scrollBounceBehavior(.basedOnSize)
                Text("Color applies to speed and gear. Controls stay neutral.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
        }
        .padding(layout.insets)
    }

    private func preview(height: CGFloat) -> some View {
        let settings = model.settings
        let tint = settings.tint.color(dark: palette.isDark)
        let weight = settings.numerals == .bold ? palette.speedWeights.bold : palette.speedWeights.regular
        let speed = model.isLive ? (model.displaySpeed ?? 0) : 0
        return VStack(spacing: 0) {
            Text(String(speed))
                .font(.system(size: 150, weight: weight))
                .monospacedDigit()
                .tracking(-7.5)
                .foregroundStyle(tint)
                .frame(height: 129)
            Text(model.unitLabel)
                .font(.system(size: 13, weight: .semibold))
                .tracking(13 * 0.24)
                .foregroundStyle(palette.text2)
                .padding(.top, 10)
            if model.isLive, model.gear != nil || model.batteryLevel != nil {
                HStack(spacing: 12) {
                    if let gear = model.gear {
                        Text(gear.rawValue).font(.system(size: 22, weight: .semibold)).foregroundStyle(tint)
                    }
                    if model.gear != nil, model.batteryLevel != nil {
                        Circle().fill(palette.text3).frame(width: 4, height: 4)
                    }
                    if let battery = model.batteryLevel {
                        Text("\(battery)%").font(.system(size: 22, weight: .medium)).foregroundStyle(palette.text2)
                    }
                }
                .padding(.top, 26)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview")
    }

    private func controls(_ settings: AppSettings) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Color").font(.system(size: 17)).foregroundStyle(palette.text)
                Spacer()
                Text(settings.tint.displayName).font(.system(size: 15)).foregroundStyle(palette.text2)
            }
            .padding(.top, 22)
            HStack(spacing: 0) {
                ForEach(SpeedTint.allCases, id: \.self) { tint in
                    let selected = tint == settings.tint
                    Button {
                        settings.tint = tint
                    } label: {
                        Circle()
                            .fill(tint.color(dark: palette.isDark))
                            .overlay(Circle().strokeBorder(palette.line, lineWidth: 1))
                            .frame(width: 38, height: 38)
                            .frame(width: 52, height: 52)
                            .overlay(Circle().strokeBorder(selected ? palette.text : .clear, lineWidth: 2))
                            .contentShape(Circle())
                    }
                    .buttonStyle(PressStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(tint.displayName)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(.top, 14)

            Hairline().padding(.top, 24)
            Text("Background").font(.system(size: 17)).foregroundStyle(palette.text).padding(.top, 18)
            Segmented(
                options: SpeedGround.allCases.map { ($0, $0.displayName(dark: palette.isDark)) },
                selection: Binding(get: { settings.ground }, set: { settings.ground = $0 }),
                accessibilityLabel: "Background",
                leading: { ground in
                    AnyView(
                        Circle()
                            .fill(Palette.make(dark: palette.isDark, ground: ground).bg)
                            .overlay(Circle().strokeBorder(palette.text3, lineWidth: 1))
                            .frame(width: 14, height: 14)
                    )
                }
            )
            .padding(.top, 12)

            Hairline().padding(.top, 22)
            Text("Numerals").font(.system(size: 17)).foregroundStyle(palette.text).padding(.top, 18)
            Segmented(
                options: [(SpeedNumerals.regular, "Regular"), (.bold, "Bold")],
                selection: Binding(get: { settings.numerals }, set: { settings.numerals = $0 }),
                accessibilityLabel: "Numerals",
                labelWeight: { $0 == .bold ? palette.speedWeights.bold : palette.speedWeights.regular }
            )
            .padding(.top, 12)
        }
    }
}
