import SwiftUI

/// Charging: level, limit and time to the limit, with electrical details
/// folded away. Charging itself is controlled in the car.
struct ChargingPage: View {
    let model: AppModel
    let layout: PageLayout
    @Environment(\.palette) private var palette
    @State private var showsDetails = false

    private var charge: ChargeReading? { model.charge }

    var body: some View {
        let hero = model.settings.tint.color(dark: palette.isDark)
        Group {
            if layout.landscape {
                HStack(spacing: 40) {
                    VStack(spacing: 0) {
                        header
                        summary(hero: hero, size: 120).frame(maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    details.frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 24) {
                    header
                    summary(hero: hero, size: 150).frame(maxHeight: .infinity)
                    details
                }
            }
        }
        .padding(layout.insets)
    }

    private var header: some View {
        HStack(spacing: 14) {
            CircleNavButton(glyph: .chevronDown, label: String(localized: "Back to dashboard"), action: model.closePage)
            HStack(spacing: 6) {
                Icon(.bolt, size: 14)
                Text(charge?.isFastCharger == true ? String(localized: "SUPERCHARGING") : String(localized: "CHARGING"))
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(13 * 0.12)
            }
            .foregroundStyle(palette.text2)
            Spacer()
        }
        .frame(height: 44)
    }

    private func summary(hero: Color, size: CGFloat) -> some View {
        let level = charge?.batteryLevel
        let limit = charge?.limitPercent
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(level.map(String.init) ?? "–")
                    .font(.system(size: size, weight: palette.speedRegular))
                    .monospacedDigit()
                    .tracking(-0.05 * size)
                    .foregroundStyle(hero)
                Text("%").font(.system(size: 28, weight: .medium)).foregroundStyle(palette.text2)
            }
            GeometryReader { bar in
                ZStack(alignment: .bottomLeading) {
                    Capsule().fill(palette.line).frame(height: 8)
                    Capsule().fill(hero).frame(width: bar.size.width * CGFloat(level ?? 0) / 100, height: 8)
                    if let limit {
                        let x = bar.size.width * CGFloat(limit) / 100
                        RoundedRectangle(cornerRadius: 1)
                            .fill(palette.text)
                            .frame(width: 2, height: 16)
                            .offset(x: x - 1, y: 4)
                        Text("\(limit)%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.text2)
                            .fixedSize()
                            .position(x: x, y: 8)
                    }
                }
            }
            .frame(height: 34)
            .padding(.top, 28)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "\(level ?? 0) percent, limit \(limit ?? 0) percent"))
            if let minutes = charge?.minutesToLimit ?? charge?.minutesToFull, minutes > 0 {
                Text(limit.map { String(localized: "\(model.minutesLabel(Double(minutes))) to \($0)%") } ?? String(localized: "\(model.minutesLabel(Double(minutes))) until fully charged"))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .padding(.top, 20)
            } else if charge?.status == .complete {
                Text(String(localized: "Charging complete"))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .padding(.top, 20)
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                if let power = charge?.powerKW { chip(.bolt, "\(power) kW") }
                if let range = model.rangeLabel { chip(.range, range) }
            }
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showsDetails.toggle() }
            } label: {
                HStack {
                    Text(String(localized: "Details")).font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Icon(.chevronDown, size: 18).rotationEffect(.degrees(showsDetails ? 180 : 0))
                }
                .foregroundStyle(palette.text2)
                .padding(.horizontal, 4)
                .frame(height: 48)
                .overlay(alignment: .top) { Hairline() }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(showsDetails ? String(localized: "Expanded") : String(localized: "Collapsed"))
            if showsDetails {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 12) {
                    stat(String(localized: "Voltage"), charge?.voltage.map { "\($0) V" })
                    stat(String(localized: "Current"), charge?.currentAmps.map { "\($0) A" })
                    stat(String(localized: "Added"), charge?.energyAddedKWh.map { String(format: "%.1f kWh", locale: Locale.current, $0) })
                    stat(String(localized: "To full"), charge?.minutesToFull.map { model.minutesLabel(Double($0)) })
                }
                .transition(.opacity)
            }
        }
    }

    private func chip(_ glyph: VelaGlyph, _ value: String) -> some View {
        HStack(spacing: 6) {
            Icon(glyph, size: 16).foregroundStyle(palette.text2)
            Text(value).font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.text)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Capsule().fill(palette.panel))
    }

    private func stat(_ label: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 13)).foregroundStyle(palette.text2)
            Text(value ?? "–").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.text)
        }
    }
}
