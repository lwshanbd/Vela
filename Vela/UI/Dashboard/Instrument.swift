import SwiftUI

/// What one rendering of the dashboard shows. The settings preview forces
/// driving or parked and shows every enabled module even without data.
@MainActor
struct DashContext {
    let model: AppModel
    let layout: DashboardLayout
    let landscape: Bool
    let parked: Bool
    let live: Bool
    let preview: Bool

    var entries: [ModuleEntry] { model.settings.dashboard.entries(landscape: landscape) }

    func isOn(_ module: DashboardModule) -> Bool {
        entries.first { $0.module == module }?.isOn ?? false
    }

    /// Chips shown: enabled chip modules with data, in list order.
    var chipModules: [DashboardModule] {
        entries.filter { $0.isOn && $0.module.isChip && (preview || hasData($0.module)) }.map(\.module)
    }

    var showsPower: Bool {
        live && !parked && isOn(.power) && (preview || model.powerKW != nil)
    }

    var showsParkPanel: Bool { parked && live }

    func hasData(_ module: DashboardModule) -> Bool {
        switch module {
        case .power: model.powerKW != nil
        case .range: model.rangeLabel != nil
        case .temps: model.insideTempLabel != nil || model.outsideTempLabel != nil
        case .heading: model.headingLabel != nil
        case .nav: model.route != nil && !parked
        case .map: model.location != nil
        case .climate: model.hasClimate
        case .media: model.hasMedia
        }
    }
}

/// Header row: connection dot and car name (or the driving alert), and the
/// settings button when parked or disconnected.
struct StatusHeader: View {
    let context: DashContext
    @Environment(\.palette) private var palette
    @State private var showsName = true

    private var model: AppModel { context.model }

    var body: some View {
        HStack {
            if let alert = context.preview ? nil : model.drivingAlert {
                HStack(spacing: 8) {
                    Icon(alert.icon, size: 16)
                    Text(alert.label)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(palette.warn)
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .frame(height: 32)
                .background(Capsule().fill(palette.panel))
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.updatesFrequently)
            } else {
                HStack(spacing: 8) {
                    Circle().fill(dotColor).frame(width: 7, height: 7)
                    Text(model.vehicleName)
                        .font(.system(size: 13, weight: .medium))
                        .tracking(13 * 0.01)
                        .foregroundStyle(palette.text2)
                        .opacity(context.live && showsName ? 1 : 0)
                }
                .padding(.leading, 4)
                .animation(.easeInOut(duration: 0.2), value: model.link)
                .animation(.easeInOut(duration: 0.2), value: showsName)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityStatus)
            }
            Spacer()
            if !context.preview, !context.live || context.parked {
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
        .animation(.easeInOut(duration: 0.2), value: context.parked)
        .task(id: model.link) {
            // Car name fades out 3 s after connecting; the dot stays.
            showsName = true
            guard model.link == .connected, !context.preview else { return }
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
        case .asleep: "\(model.vehicleName) is asleep"
        case .lost: "Connection lost"
        case .bluetoothOff: "Bluetooth off"
        case .bluetoothUnauthorized: "Bluetooth access off"
        case .idle, .connecting: "Connecting"
        }
    }
}

/// Speed, unit, power, gear and battery, chips (column layouts), or the
/// connection message when not live.
struct InstrumentView: View {
    let context: DashContext
    @Environment(\.palette) private var palette

    private var model: AppModel { context.model }
    private var layout: DashboardLayout { context.layout }
    private var column: Bool { layout.arrangement == .column }

    var body: some View {
        let tint = model.settings.tint.color(dark: palette.isDark)
        let weight = model.settings.numerals == .bold ? palette.speedBold : palette.speedRegular
        let size = context.parked ? layout.parkedSpeed : layout.speed
        VStack(spacing: 0) {
            if context.live, let speed = context.parked ? 0 : model.displaySpeed {
                Text(String(speed))
                    .font(.system(size: size, weight: weight))
                    .monospacedDigit()
                    .tracking(-0.05 * size)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(height: size * 0.86)
                    .contentTransition(.identity)
                    .accessibilityLabel("\(speed) \(model.settings.units == .mph ? "miles per hour" : "kilometers per hour")")
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(palette.text3)
                    .frame(width: column ? 96 : 88, height: 6)
                    .frame(height: size * 0.86)
                    .accessibilityHidden(true)
            }
            Text(model.unitLabel)
                .font(.system(size: layout.unitSize, weight: .semibold))
                .tracking(layout.unitSize * 0.24)
                .padding(.leading, layout.unitSize * 0.24)
                .foregroundStyle(context.live ? palette.text2 : palette.text3)
                .padding(.top, 12)
                .accessibilityHidden(true)

            if context.live {
                if context.showsPower {
                    PowerBar(kw: model.powerKW ?? 0, halfWidth: column ? 72 : 64, tint: tint)
                        .padding(.top, 18)
                }
                GearRow(model: model, parked: context.parked, size: layout.rowSize, tint: tint)
                    .padding(.top, context.parked ? (column ? 22 : 18) : (column ? 34 : 24))
                if column, !context.chipModules.isEmpty {
                    ChipRow(context: context)
                        .padding(.top, 24)
                }
                if !column, context.showsParkPanel {
                    ParkPanel(context: context)
                        .padding(.top, 18)
                }
            } else {
                ConnectionMessage(model: model)
                    .padding(.top, 32)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: context.live)
    }
}

/// Bolt, a bar centered on zero, and the kW value. Regen fills left in the tint.
struct PowerBar: View {
    let kw: Int
    let halfWidth: CGFloat
    let tint: Color
    @Environment(\.palette) private var palette

    var body: some View {
        let width = min(halfWidth, (CGFloat(abs(kw)) / 150 * halfWidth).rounded())
        HStack(spacing: 10) {
            Icon(.bolt, size: 16).foregroundStyle(palette.text2)
            ZStack(alignment: .leading) {
                Capsule().fill(palette.line).frame(width: halfWidth * 2, height: 4)
                Capsule()
                    .fill(kw >= 0 ? palette.text : tint)
                    .frame(width: width, height: 4)
                    .offset(x: kw >= 0 ? halfWidth : halfWidth - width)
                RoundedRectangle(cornerRadius: 1)
                    .fill(palette.text3)
                    .frame(width: 2, height: 12)
                    .offset(x: halfWidth - 1)
            }
            .frame(width: halfWidth * 2, height: 12)
            Text("\(kw < 0 ? "−" : "")\(abs(kw)) kW")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(palette.text)
                .frame(width: 58, alignment: .leading)
        }
        .frame(height: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Power \(kw) kilowatts")
    }
}

/// Gear · battery. Tapping the battery while charging opens Charging.
struct GearRow: View {
    let model: AppModel
    let parked: Bool
    let size: CGFloat
    let tint: Color
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            if let gear = parked ? .park : model.gear {
                Text(gear.rawValue)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityLabel("Gear \(gear.rawValue)")
            }
            if model.gear != nil || parked, model.batteryLevel != nil {
                Circle().fill(palette.text3).frame(width: 4, height: 4)
            }
            if let battery = model.batteryLevel {
                Button {
                    if model.isCharging { model.open(.charging) }
                } label: {
                    HStack(spacing: 8) {
                        BatteryGlyph(level: battery, width: size - 1, height: size / 2, color: palette.text2)
                        Text("\(battery)%")
                            .font(.system(size: size, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(palette.text2)
                    }
                }
                .buttonStyle(.plain)
                .allowsHitTesting(model.isCharging)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Battery \(battery) percent")
                .accessibilityAddTraits(model.isCharging ? .isButton : [])
            }
        }
        .frame(height: size)
    }
}

/// Range, inside/outside temperature and heading in one capsule.
struct ChipRow: View {
    let context: DashContext
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(context.chipModules.enumerated()), id: \.element) { index, module in
                if index > 0 {
                    Rectangle().fill(palette.line).frame(width: 1, height: 18)
                        .padding(.leading, 2).padding(.trailing, 14)
                }
                HStack(spacing: 12) {
                    ForEach(parts(module), id: \.0) { glyph, value in
                        HStack(spacing: 6) {
                            Icon(glyph, size: 16).foregroundStyle(palette.text2)
                            Text(value)
                                .font(.system(size: 17, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(palette.text)
                        }
                    }
                }
                .padding(.trailing, index < context.chipModules.count - 1 ? 12 : 0)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Capsule().fill(palette.panel))
        .accessibilityElement(children: .combine)
    }

    private func parts(_ module: DashboardModule) -> [(VelaGlyph, String)] {
        let model = context.model
        switch module {
        case .range:
            return [(.range, model.rangeLabel ?? "–")]
        case .temps:
            return [(.car, model.insideTempLabel ?? "–"), (.sun, model.outsideTempLabel ?? "–")]
        case .heading:
            return [(.compass, model.headingLabel ?? "–")]
        default:
            return []
        }
    }
}

/// Connecting / asleep / lost / Bluetooth messages under the speed.
struct ConnectionMessage: View {
    let model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL

    var body: some View {
        let (title, color, subtitle): (String, Color, String?) = switch model.link {
        case .asleep: ("\(model.vehicleName) is asleep", palette.text2, "Vela connects when someone opens a door.")
        case .lost: ("Connection lost", palette.warn, "Reconnecting automatically")
        case .bluetoothOff: ("Bluetooth is off", palette.text, "Turn it on in Control Center")
        case .bluetoothUnauthorized: ("Bluetooth access is off", palette.text, "Vela needs Bluetooth to talk to your car.")
        case .idle, .connecting, .connected: ("Connecting to \(model.vehicleName)", palette.text2, nil)
        }
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.text2)
            }
            if model.link == .connecting || model.link == .idle {
                IndeterminateBar().padding(.top, 6)
            }
            if model.link == .bluetoothUnauthorized {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.bg)
                        .padding(.horizontal, 22)
                        .frame(height: 48)
                        .background(Capsule().fill(palette.text))
                }
                .buttonStyle(PressStyle())
                .padding(.top, 10)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 300)
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

/// Parked: a small top view of the car with anything open or low marked,
/// the lock state, and an entry to the Vehicle page.
struct ParkPanel: View {
    let context: DashContext
    @Environment(\.palette) private var palette

    private var model: AppModel { context.model }

    var body: some View {
        let count = model.attentionCount
        let locked = model.closures?.locked
        Button {
            model.open(.vehicle)
        } label: {
            HStack(spacing: 16) {
                CarGlyph(open: model.openParts, lowTires: model.tireWarnings)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Icon(locked == false ? .unlock : .lock, size: 16)
                        Text(locked == nil ? "Vehicle" : locked! ? "Locked" : "Unlocked")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(palette.text)
                    Text(count == 0 ? "All closed" : "\(count) need attention")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(count == 0 ? palette.text2 : palette.warn)
                }
                Spacer(minLength: 0)
                if model.showsUpdateBadge {
                    HStack(spacing: 6) {
                        Icon(.update, size: 14)
                        Text("Update").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Capsule().fill(palette.pbtn))
                }
                Icon(.chevronRight, size: 18).foregroundStyle(palette.text3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 92)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.panel))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Vehicle status, \(locked == false ? "unlocked" : "locked"), \(count == 0 ? "all closed" : "\(count) need attention")")
    }
}

/// 40 × 74 top view of the car from the design, with open doors, trunks and
/// low tires marked in the attention color.
struct CarGlyph: View {
    let open: Set<ClosuresReading.Part>
    let lowTires: Set<TireReading.Position>
    @Environment(\.palette) private var palette

    var body: some View {
        let palette = palette
        Canvas { context, _ in
            func stroke(_ d: String, _ color: Color, _ width: CGFloat = 1.5) {
                context.stroke(SVGPath.parse(d), with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            func tire(_ x: CGFloat, _ y: CGFloat, _ low: Bool) {
                context.fill(
                    Path(roundedRect: CGRect(x: x, y: y, width: 4, height: 10), cornerRadius: 1.5),
                    with: .color(low ? palette.warn : palette.text3)
                )
            }
            let warn = palette.warn, neutral = palette.text3
            stroke("M17 4h6a9 9 0 0 1 9 9v44a9 9 0 0 1-9 9h-6a9 9 0 0 1-9-9V13a9 9 0 0 1 9-9z", palette.text2)
            stroke("M12 21h16M12 49h16", neutral)
            let trunk = open.contains(.trunk)
            stroke("M13 65.5h14", trunk ? warn : neutral, trunk ? 3 : 1.5)
            if trunk { stroke("M12 67 L10 72 H30 L28 67", warn) }
            if open.contains(.frunk) { stroke("M12 3 L10 -2 H30 L28 3", warn) }
            let doors: [(ClosuresReading.Part, String)] = [
                (.frontLeftDoor, "M8 24v11"), (.rearLeftDoor, "M8 38v11"),
                (.frontRightDoor, "M32 24v11"), (.rearRightDoor, "M32 38v11"),
            ]
            for (part, d) in doors {
                let isOpen = open.contains(part)
                stroke(d, isOpen ? warn : neutral, isOpen ? 3 : 1.5)
            }
            tire(3, 11, lowTires.contains(.frontLeft))
            tire(33, 11, lowTires.contains(.frontRight))
            tire(3, 51, lowTires.contains(.rearLeft))
            tire(33, 51, lowTires.contains(.rearRight))
        }
        .frame(width: 40, height: 74)
        .accessibilityHidden(true)
    }
}
