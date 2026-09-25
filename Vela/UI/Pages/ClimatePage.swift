import SwiftUI

/// Climate: per-zone setpoints, zone sync, fan readout and power. Fan speed
/// and fan Auto have no BLE command (`VehicleCapabilities.fanControl`), so the
/// fan row is a readout only.
struct ClimatePage: View {
    let model: AppModel
    let layout: PageLayout
    @Environment(\.palette) private var palette

    var body: some View {
        let isOn = model.climate?.isOn ?? false
        VStack(spacing: 0) {
            PageHeader(title: "CLIMATE", speed: (model.displaySpeed, model.unitLabel)) {
                model.closePage()
            }
            if layout.landscape {
                HStack(alignment: .center, spacing: 40) {
                    zones
                        .opacity(isOn ? 1 : 0.32)
                        .frame(maxWidth: .infinity)
                    VStack(spacing: 0) {
                        VStack(spacing: 20) {
                            syncRow
                            fan
                        }
                        .opacity(isOn ? 1 : 0.32)
                        Spacer(minLength: 16)
                        power
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 16)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        zones.padding(.top, layout.contentHeight < 640 ? 24 : 40)
                        syncRow.padding(.top, 32)
                        fan.padding(.top, 20)
                    }
                    .opacity(isOn ? 1 : 0.32)
                }
                .scrollBounceBehavior(.basedOnSize)
                power
            }
        }
        .padding(layout.insets)
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }

    private var zones: some View {
        let sync = model.settings.syncClimateZones
        return HStack(spacing: 0) {
            zone(
                title: "DRIVER", celsius: model.driverSetpointC, color: palette.text, controlsOpacity: 1,
                down: { model.adjustDriverTemperature(by: -1) }, up: { model.adjustDriverTemperature(by: 1) }
            )
            Hairline(vertical: true)
            zone(
                title: "PASSENGER", celsius: model.passengerSetpointC,
                color: sync ? palette.text2 : palette.text, controlsOpacity: sync ? 0.4 : 1,
                down: { model.adjustPassengerTemperature(by: -1) }, up: { model.adjustPassengerTemperature(by: 1) }
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func zone(
        title: String, celsius: Double?, color: Color, controlsOpacity: Double,
        down: @escaping () -> Void, up: @escaping () -> Void
    ) -> some View {
        let label = model.temperatureLabel(celsius)
        let who = title.lowercased()
        return VStack(spacing: 6) {
            TrackedLabel(text: title)
            Text(label)
                .font(.system(size: 72, weight: .regular))
                .monospacedDigit()
                .tracking(-0.03 * 72)
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(height: 72 * 1.05)
                .accessibilityLabel("\(title.capitalized) \(label)")
            HStack(spacing: 12) {
                RoundIconButton(.minus, diameter: 64, iconSize: 24, label: "Lower \(who) temperature", action: down)
                RoundIconButton(.plus, diameter: 64, iconSize: 24, label: "Raise \(who) temperature", action: up)
            }
            .opacity(controlsOpacity)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private var syncRow: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack {
                Text("Sync both sides")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(palette.text)
                Spacer()
                VelaSwitch(
                    isOn: Binding(get: { model.settings.syncClimateZones }, set: { model.setSyncZones($0) }),
                    label: "Sync both sides"
                )
            }
            .frame(height: 68)
            Hairline()
        }
    }

    @ViewBuilder
    private var fan: some View {
        if let level = model.climate?.fanLevel {
            let bars = 10
            VStack(spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Fan")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(palette.text)
                    Text(level == 0 ? "Off" : String(level))
                        .font(.system(size: 17))
                        .foregroundStyle(palette.text2)
                    Spacer()
                }
                HStack(spacing: 4) {
                    ForEach(0 ..< bars, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index < level ? palette.text : palette.fill2)
                    }
                }
                .frame(height: 22)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Fan speed \(level == 0 ? "off" : String(level))")
        }
    }

    private var power: some View {
        let isOn = model.climate?.isOn ?? false
        return HStack(spacing: 4) {
            powerOption(title: "Off", selected: !isOn, showsIcon: false) { model.setClimate(on: false) }
            powerOption(title: "On", selected: isOn, showsIcon: true) { model.setClimate(on: true) }
        }
        .padding(4)
        .frame(height: 64)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.fill))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Climate power")
    }

    private func powerOption(title: String, selected: Bool, showsIcon: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if showsIcon { Icon(.power, size: 18) }
                Text(title).font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(selected ? palette.bg : palette.text2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(selected ? palette.text : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
