import SwiftUI

/// Climate: power, per-zone setpoints, seats, wheel, defrost and a fan
/// readout; parked adds what the car keeps doing when you leave. Fan speed
/// and fan Auto have no BLE command, so the fan is shown, not controlled.
struct ClimatePage: View {
    let model: AppModel
    let layout: PageLayout
    @Environment(\.palette) private var palette

    private var climate: ClimateReading? { model.climate }

    var body: some View {
        let isOn = climate?.isOn ?? false
        PageScaffold(layout: layout) {
            PageHeader(title: String(localized: "CLIMATE"), onBack: model.closePage) {
                if model.isInGear { HeaderSpeed(value: model.displaySpeed, unit: model.unitLabel) }
            }
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                Segmented(
                    options: [(false, String(localized: "Off")), (true, String(localized: "On"))],
                    selection: climate.map(\.isOn),
                    accessibilityLabel: String(localized: "Climate power"),
                    height: 56
                ) { model.climateAction(.power($0)) }
                    .padding(.top, 20)
                if let temps = insideOutside {
                    Text(temps)
                        .font(.system(size: 15))
                        .foregroundStyle(palette.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                }
                zones
                    .opacity(isOn ? 1 : 0.32)
                    .padding(.top, 24)
                Hairline().padding(.top, 20)
                SwitchRow(title: String(localized: "Sync both sides"), isOn: model.settings.syncClimateZones) {
                    model.setSyncZones(!model.settings.syncClimateZones)
                }
                seats
                wheelAndDefrost
                fanRow
                if model.isParked {
                    whenYouLeave
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }

    private var insideOutside: String? {
        let inside = model.insideTempLabel, outside = model.outsideTempLabel
        switch (inside, outside) {
        case let (i?, o?): return String(localized: "Inside \(i) · Outside \(o)")
        case let (i?, nil): return String(localized: "Inside \(i)")
        case let (nil, o?): return String(localized: "Outside \(o)")
        default: return nil
        }
    }

    private var zones: some View {
        let sync = model.settings.syncClimateZones
        return HStack(spacing: 0) {
            zone(
                title: String(localized: "DRIVER"), celsius: model.driverSetpointC, color: palette.text, controlsOpacity: 1,
                down: { model.adjustDriverTemperature(by: -1) }, up: { model.adjustDriverTemperature(by: 1) }
            )
            Hairline(vertical: true)
            zone(
                title: String(localized: "PASSENGER"), celsius: model.passengerSetpointC,
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
        return VStack(spacing: 4) {
            TrackedLabel(text: title)
            Text(label)
                .font(.system(size: 64, weight: .regular))
                .monospacedDigit()
                .tracking(-0.03 * 64)
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(height: 64 * 1.05)
                .accessibilityLabel("\(title.capitalized) \(label)")
            HStack(spacing: 12) {
                RoundIconButton(.minus, diameter: 64, iconSize: 24, fill: palette.fill, label: String(localized: "Lower \(who) temperature"), action: down)
                RoundIconButton(.plus, diameter: 64, iconSize: 24, fill: palette.fill, label: String(localized: "Raise \(who) temperature"), action: up)
            }
            .opacity(controlsOpacity)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var seats: some View {
        let front: [(ClimateReading.Seat, String)] = [(.frontLeft, String(localized: "Driver")), (.frontRight, String(localized: "Passenger"))]
        let rear: [(ClimateReading.Seat, String)] = [(.rearLeft, String(localized: "Rear left")), (.rearCenter, String(localized: "Center")), (.rearRight, String(localized: "Rear right"))]
        let frontHeat = front.filter { model.seatHeatLevel($0.0) != nil }
        let rearHeat = rear.filter { model.seatHeatLevel($0.0) != nil }
        let cool = front.filter { model.seatCoolLevel($0.0) != nil }
        if !frontHeat.isEmpty || !rearHeat.isEmpty {
            TrackedLabel(text: String(localized: "SEAT HEATING")).padding(.top, 24)
            VStack(spacing: 10) {
                seatGrid(frontHeat, glyph: .heat, dash: 18) { model.seatHeatLevel($0) } tap: { model.cycleSeatHeat($0) }
                seatGrid(rearHeat, glyph: nil, dash: 14) { model.seatHeatLevel($0) } tap: { model.cycleSeatHeat($0) }
            }
            .padding(.top, 12)
        }
        if !cool.isEmpty {
            TrackedLabel(text: String(localized: "SEAT COOLING")).padding(.top, 24)
            seatGrid(cool, glyph: .cool, dash: 18) { model.seatCoolLevel($0) } tap: { model.cycleSeatCool($0) }
                .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func seatGrid(
        _ seats: [(ClimateReading.Seat, String)], glyph: VelaGlyph?, dash: CGFloat,
        level: @escaping (ClimateReading.Seat) -> Int?, tap: @escaping (ClimateReading.Seat) -> Void
    ) -> some View {
        if !seats.isEmpty {
            let hot = model.settings.tint.color(dark: palette.isDark)
            HStack(spacing: 10) {
                ForEach(seats, id: \.0) { seat, name in
                    let value = level(seat) ?? 0
                    Button {
                        tap(seat)
                    } label: {
                        VStack(spacing: 7) {
                            HStack(spacing: 8) {
                                if let glyph { Icon(glyph, size: 18) }
                                Text(name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                            }
                            .foregroundStyle(value > 0 ? palette.text : palette.text2)
                            HStack(spacing: 5) {
                                ForEach(1 ... 3, id: \.self) { step in
                                    Capsule()
                                        .fill(value >= step ? hot : palette.fill2)
                                        .frame(width: dash, height: 4)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.fill))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(String(localized: "\(name) seat"))
                    .accessibilityValue(String(localized: "Level \(value) of 3"))
                }
            }
        }
    }

    @ViewBuilder
    private var wheelAndDefrost: some View {
        Hairline().padding(.top, 24)
        if let wheel = climate?.steeringWheelHeat {
            SwitchRow(title: String(localized: "Steering wheel heat"), isOn: wheel) { model.climateAction(.steeringWheelHeat(!wheel)) }
        }
        if let auto = climate?.autoSeatClimate {
            SwitchRow(title: String(localized: "Auto seat climate"), isOn: auto) { model.climateAction(.autoSeatClimate(!auto)) }
        }
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Defrost")).font(.system(size: 17)).foregroundStyle(palette.text)
                if let detail = defrostDetail {
                    Text(detail).font(.system(size: 15)).foregroundStyle(palette.text2)
                }
            }
            Spacer()
            let max = climate?.maxDefrost ?? false
            PillButton(title: String(localized: "Max defrost"), selected: max) { model.climateAction(.maxDefrost(!max)) }
        }
        .frame(minHeight: 64)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var defrostDetail: String? {
        func word(_ on: Bool?) -> String? { on.map { $0 ? String(localized: "on") : String(localized: "off") } }
        switch (word(climate?.frontDefroster), word(climate?.rearDefroster)) {
        case let (f?, r?): return String(localized: "Front \(f) · Rear \(r)")
        case let (f?, nil): return String(localized: "Front \(f)")
        case let (nil, r?): return String(localized: "Rear \(r)")
        default: return nil
        }
    }

    @ViewBuilder
    private var fanRow: some View {
        if let level = climate?.fanLevel {
            HStack {
                Text(String(localized: "Fan")).font(.system(size: 17)).foregroundStyle(palette.text)
                Spacer()
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0 ..< 10, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(index < level ? palette.text2 : palette.fill2)
                            .frame(width: 4, height: CGFloat(6 + index))
                    }
                }
                .frame(height: 16, alignment: .bottom)
                Text(level == 0 ? String(localized: "Off") : "\(level)")
                    .font(.system(size: 17))
                    .foregroundStyle(palette.text2)
                    .frame(minWidth: 20, alignment: .trailing)
                    .padding(.leading, 12)
            }
            .frame(height: 60)
            .overlay(alignment: .bottom) { Hairline() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Fan speed \(level == 0 ? String(localized: "off") : String(level))"))
        }
    }

    @ViewBuilder
    private var whenYouLeave: some View {
        TrackedLabel(text: String(localized: "WHEN YOU LEAVE THE CAR")).padding(.top, 32)
        if climate?.keeperMode != nil || climate != nil {
            Text(String(localized: "Keep climate on")).font(.system(size: 17)).foregroundStyle(palette.text).padding(.top, 16)
            Segmented(
                options: [(ClimateReading.KeeperMode.off, String(localized: "Off")), (.on, String(localized: "On")), (.dog, String(localized: "Dog")), (.camp, String(localized: "Camp"))],
                selection: climate?.keeperMode,
                accessibilityLabel: String(localized: "Keep climate on")
            ) { model.climateAction(.keeper($0)) }
                .padding(.top, 12)
        }
        Text(String(localized: "Cabin overheat protection")).font(.system(size: 17)).foregroundStyle(palette.text).padding(.top, 24)
        Segmented(
            options: [(ClimateReading.OverheatProtection.off, String(localized: "Off")), (.on, String(localized: "On")), (.fanOnly, String(localized: "Fan only"))],
            selection: climate?.overheatProtection,
            accessibilityLabel: String(localized: "Cabin overheat protection")
        ) { model.climateAction(.overheatProtection($0)) }
            .padding(.top, 12)
        HStack {
            Text(String(localized: "Starts at")).font(.system(size: 15)).foregroundStyle(palette.text2)
            Spacer()
            HStack(spacing: 6) {
                ForEach([(ClimateReading.OverheatTemp.low, String(localized: "Low")), (.medium, String(localized: "Medium")), (.high, String(localized: "High"))], id: \.0) { level, name in
                    PillButton(title: name, selected: climate?.overheatTemp == level) {
                        model.climateAction(.overheatTemp(level))
                    }
                }
            }
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) { Hairline() }
        if let bio = climate?.bioweaponMode {
            SwitchRow(title: String(localized: "Bioweapon defense"), isOn: bio) { model.climateAction(.bioweapon(!bio)) }
        }
        if let heaters = heaterLine {
            Text(heaters)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(palette.text2)
                .padding(.top, 16)
        }
    }

    private var heaterLine: String? {
        var parts: [String] = []
        if let on = climate?.batteryHeater { parts.append(String(localized: "Battery heater \(on ? String(localized: "on") : String(localized: "off"))")) }
        if let on = climate?.wiperHeater { parts.append(String(localized: "Wiper heater \(on ? String(localized: "on") : String(localized: "off"))")) }
        if let on = climate?.mirrorHeaters { parts.append(String(localized: "Mirror heaters \(on ? String(localized: "on") : String(localized: "off"))")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
