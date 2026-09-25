import SwiftUI

/// Sizes that differ between portrait and landscape; everything else about
/// the instrument is shared.
struct InstrumentMetrics {
    var speedSize: CGFloat
    var unitSize: CGFloat
    var unitTop: CGFloat
    var rowTop: CGFloat
    var rowSize: CGFloat
    var battery: CGSize
    var placeholderWidth: CGFloat

    static func portrait(speedSize: CGFloat) -> InstrumentMetrics {
        InstrumentMetrics(
            speedSize: speedSize, unitSize: 15, unitTop: 12, rowTop: 36, rowSize: 26,
            battery: CGSize(width: 25, height: 13), placeholderWidth: 96
        )
    }

    static func landscape(speedSize: CGFloat) -> InstrumentMetrics {
        InstrumentMetrics(
            speedSize: speedSize, unitSize: 14, unitTop: 10, rowTop: 28, rowSize: 24,
            battery: CGSize(width: 24, height: 12), placeholderWidth: 88
        )
    }
}

/// Header row: connection dot with the car's name, and the settings button
/// when parked or disconnected.
struct StatusHeader: View {
    let model: AppModel
    @Environment(\.palette) private var palette
    @State private var showsName = true

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(dotColor).frame(width: 7, height: 7)
                Text(model.vehicleName)
                    .font(.system(size: 13, weight: .medium))
                    .tracking(13 * 0.01)
                    .foregroundStyle(palette.text2)
                    .opacity(model.link == .connected && showsName ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.2), value: model.link)
            .animation(.easeInOut(duration: 0.2), value: showsName)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityStatus)
            Spacer()
            if model.showsSettingsButton {
                Button {
                    model.open(.settings)
                } label: {
                    Icon(.sliders, size: 22)
                        .foregroundStyle(palette.text2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Settings")
                .transition(.opacity)
            }
        }
        .frame(height: 44)
        .animation(.easeInOut(duration: 0.2), value: model.showsSettingsButton)
        .task(id: model.link) {
            // Car name fades out 3 s after connecting; the dot stays.
            showsName = true
            guard model.link == .connected else { return }
            try? await Task.sleep(for: .seconds(3))
            showsName = false
        }
    }

    private var dotColor: Color {
        switch model.link {
        case .lost, .bluetoothOff, .bluetoothUnauthorized: palette.warn
        default: palette.text2
        }
    }

    private var accessibilityStatus: String {
        switch model.link {
        case .connected: "Connected to \(model.vehicleName)"
        case .lost: "Connection lost"
        case .bluetoothOff: "Bluetooth off"
        case .bluetoothUnauthorized: "Bluetooth not allowed"
        case .idle, .connecting: "Connecting"
        }
    }
}

/// Speed, unit, gear and battery, or the connection message when not live.
struct InstrumentView: View {
    let model: AppModel
    let metrics: InstrumentMetrics
    @Environment(\.palette) private var palette

    var body: some View {
        let tint = model.settings.tint.color(dark: palette.isDark)
        let weight = model.settings.numerals == .bold ? palette.speedWeights.bold : palette.speedWeights.regular
        VStack(spacing: 0) {
            if model.isLive, let speed = model.displaySpeed {
                Text(String(speed))
                    .font(.system(size: metrics.speedSize, weight: weight))
                    .monospacedDigit()
                    .tracking(-0.05 * metrics.speedSize)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(height: metrics.speedSize * 0.86)
                    .contentTransition(.identity)
                    .accessibilityLabel("\(speed) \(model.settings.units == .mph ? "miles per hour" : "kilometers per hour")")
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(palette.text3)
                    .frame(width: metrics.placeholderWidth, height: 6)
                    .frame(height: metrics.speedSize * 0.86)
                    .accessibilityHidden(true)
            }
            Text(model.unitLabel)
                .font(.system(size: metrics.unitSize, weight: .semibold))
                .tracking(metrics.unitSize * 0.24)
                .padding(.leading, metrics.unitSize * 0.24)
                .foregroundStyle(model.isLive ? palette.text2 : palette.text3)
                .padding(.top, metrics.unitTop)
                .accessibilityHidden(true)

            Group {
                if model.isLive {
                    liveRow(tint: tint)
                } else {
                    ConnectionMessage(model: model)
                }
            }
            .padding(.top, metrics.rowTop)
        }
        .animation(.easeInOut(duration: 0.2), value: model.isLive)
    }

    @ViewBuilder
    private func liveRow(tint: Color) -> some View {
        HStack(spacing: 14) {
            if let gear = model.gear {
                Text(gear.rawValue)
                    .font(.system(size: metrics.rowSize, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityLabel("Gear \(gear.rawValue)")
            }
            if model.gear != nil, model.batteryLevel != nil {
                Circle().fill(palette.text3).frame(width: 4, height: 4)
            }
            if let battery = model.batteryLevel {
                HStack(spacing: 8) {
                    BatteryGlyph(level: battery, width: metrics.battery.width, height: metrics.battery.height, color: palette.text2)
                    Text("\(battery)%")
                        .font(.system(size: metrics.rowSize, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(palette.text2)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Battery \(battery) percent")
            }
        }
        .frame(height: metrics.rowSize)
    }
}

/// Connecting / Connection lost / Bluetooth messages under the speed.
struct ConnectionMessage: View {
    let model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch model.link {
        case .lost:
            twoLine("Connection lost", "Reconnecting automatically")
        case .bluetoothOff:
            twoLine("Bluetooth is off", "Turn it on to connect to \(model.vehicleName)")
        case .bluetoothUnauthorized:
            VStack(spacing: 6) {
                twoLine("Bluetooth not allowed", "Vela needs Bluetooth to reach your car")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.text)
                .frame(minHeight: 44)
            }
        case .idle, .connecting, .connected:
            VStack(spacing: 14) {
                Text("Connecting to \(model.vehicleName)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(palette.text2)
                IndeterminateBar()
            }
        }
    }

    private func twoLine(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(palette.warn)
            Text(detail)
                .font(.system(size: 15))
                .foregroundStyle(palette.text2)
                .multilineTextAlignment(.center)
        }
    }
}

/// 120 × 2 track with a 44 pt segment sliding across it.
struct IndeterminateBar: View {
    @Environment(\.palette) private var palette
    @State private var phase = false

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(palette.line)
            Capsule()
                .fill(palette.text2)
                .frame(width: 44)
                .offset(x: phase ? 76 : 0)
        }
        .frame(width: 120, height: 2)
        .clipped()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
        .accessibilityHidden(true)
    }
}
