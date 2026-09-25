import SwiftUI

/// Parked-only controls: locks, trunks, windows, sentry, and more. Each row
/// shows what the car reports and offers the action that changes it.
struct ControlsPage: View {
    let model: AppModel
    let layout: PageLayout
    @Environment(\.palette) private var palette
    @State private var showsMore = false

    private var closures: ClosuresReading? { model.closures }

    var body: some View {
        PageScaffold(layout: layout) {
            PageHeader(title: "CONTROLS", onBack: model.closePage)
        } content: {
            VStack(spacing: 0) {
                lockButton.padding(.top, 20)
                VStack(spacing: 0) {
                    frunkRow
                    openCloseRow(
                        glyph: .rearTrunk, name: "Rear trunk", key: "trunk",
                        isOpen: closures?.open.contains(.trunk), openWord: "Open",
                        openAction: .openTrunk, closeAction: .closeTrunk, openVerb: "Open"
                    )
                    openCloseRow(
                        glyph: .window, name: "Windows", key: "windows",
                        isOpen: closures.map { !$0.open.isDisjoint(with: [.frontLeftWindow, .frontRightWindow, .rearLeftWindow, .rearRightWindow]) },
                        openWord: "Vented", openAction: .ventWindows, closeAction: .closeWindows, openVerb: "Vent"
                    )
                    sentryRow
                }
                .padding(.top, 12)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showsMore.toggle() }
                } label: {
                    HStack {
                        Text("More").font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Icon(.chevronDown, size: 18).rotationEffect(.degrees(showsMore ? 180 : 0))
                    }
                    .foregroundStyle(palette.text2)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
                .accessibilityValue(showsMore ? "Expanded" : "Collapsed")

                if showsMore {
                    VStack(spacing: 0) {
                        if closures?.hasSunroof == true {
                            openCloseRow(
                                glyph: .sunroof, name: "Sunroof", key: "sunroof",
                                isOpen: closures?.open.contains(.sunroof), openWord: "Open",
                                openAction: .ventSunroof, closeAction: .closeSunroof, openVerb: "Vent"
                            )
                        }
                        openCloseRow(
                            glyph: .bolt, name: "Charge port", key: "port",
                            isOpen: model.charge?.portOpen, openWord: "Open",
                            openAction: .openChargePort, closeAction: .closeChargePort, openVerb: "Open"
                        )
                        if model.location?.homelinkNearby == true {
                            row(glyph: .garage, name: "Garage door", state: "Nearby", attention: false) {
                                actionButton("Open", key: "homelink") { model.control(.homelink, key: "homelink") }
                            }
                        }
                        HStack(spacing: 10) {
                            wideButton("Honk", key: "honk", action: .honk)
                            wideButton("Flash lights", key: "flash", action: .flashLights)
                        }
                        .padding(.top, 16)
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private var lockButton: some View {
        let locked = closures?.locked
        let busy = model.isBusy("lock")
        return Button {
            guard let locked else { return }
            model.control(locked ? .unlock : .lock, key: "lock")
        } label: {
            HStack(spacing: 16) {
                Icon(locked == false ? .unlock : .lock, size: 30, lineWidth: 1.7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(locked == nil ? "–" : locked! ? "Locked" : "Unlocked")
                        .font(.system(size: 24, weight: .semibold))
                    Text(locked == nil ? "Waiting for the car" : "Tap to \(locked! ? "unlock" : "lock")")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.text2)
                }
                Spacer()
                if busy { ProgressView() }
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, 22)
            .frame(height: 84)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(palette.panel))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(locked == nil || busy)
        .accessibilityLabel(locked == nil ? "Lock state unknown" : locked! ? "Locked. Unlock the car" : "Unlocked. Lock the car")
    }

    /// The front trunk can be opened over BLE but not closed.
    private var frunkRow: some View {
        let isOpen = closures?.open.contains(.frunk)
        return row(glyph: .frontTrunk, name: "Front trunk", state: stateWord(isOpen, open: "Open"), attention: isOpen == true) {
            if isOpen == false {
                actionButton("Open", key: "frunk") { model.control(.openFrunk, key: "frunk") }
            }
        }
    }

    private var sentryRow: some View {
        let sentry = closures?.sentry
        let isOn = sentry.map { $0 != .off }
        let state: String = switch sentry {
        case .off?: "Off"
        case .idle?: "Standby"
        case .armed?: "Armed"
        case .aware?: "Aware"
        case .panic?: "Alarm"
        case .quiet?: "Quiet"
        case nil: "–"
        }
        return row(glyph: .eye, name: "Sentry Mode", state: state, attention: false) {
            if let isOn {
                VelaSwitch(isOn: isOn, label: "Sentry Mode") { model.control(.sentry(!isOn), key: "sentry") }
            }
        }
    }

    private func openCloseRow(
        glyph: VelaGlyph, name: String, key: String, isOpen: Bool?, openWord: String,
        openAction: VehicleConnection.ControlAction, closeAction: VehicleConnection.ControlAction, openVerb: String
    ) -> some View {
        row(glyph: glyph, name: name, state: stateWord(isOpen, open: openWord), attention: isOpen == true) {
            if let isOpen {
                actionButton(isOpen ? "Close" : openVerb, key: key) {
                    model.control(isOpen ? closeAction : openAction, key: key)
                }
            }
        }
    }

    private func stateWord(_ isOpen: Bool?, open: String) -> String {
        switch isOpen {
        case true?: open
        case false?: "Closed"
        case nil: "–"
        }
    }

    private func row(
        glyph: VelaGlyph, name: String, state: String, attention: Bool,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: 14) {
            Icon(glyph, size: 22).foregroundStyle(attention ? palette.warn : palette.text2)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 17)).foregroundStyle(palette.text)
                Text(state).font(.system(size: 13, weight: .medium)).foregroundStyle(attention ? palette.warn : palette.text2)
            }
            Spacer()
            trailing()
        }
        .frame(minHeight: 64)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func actionButton(_ title: String, key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(model.isBusy(key) ? 0 : 1)
                if model.isBusy(key) { ProgressView() }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 16)
            .frame(minWidth: 84, minHeight: 44)
            .background(Capsule().fill(palette.fill))
        }
        .buttonStyle(PressStyle())
        .disabled(model.isBusy(key))
    }

    private func wideButton(_ title: String, key: String, action: VehicleConnection.ControlAction) -> some View {
        Button {
            model.control(action, key: key)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.fill))
        }
        .buttonStyle(PressStyle())
        .disabled(model.isBusy(key))
    }
}
