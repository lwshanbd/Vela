import SwiftUI

struct SettingsPage: View {
    let model: AppModel
    let layout: PageLayout
    @State private var showsSpeedDisplay = false

    var body: some View {
        ZStack {
            if showsSpeedDisplay {
                SpeedDisplayPage(model: model, layout: layout) {
                    withAnimation(.easeOut(duration: 0.28)) { showsSpeedDisplay = false }
                }
                .transition(.move(edge: .trailing))
            } else {
                SettingsRoot(model: model, layout: layout) {
                    withAnimation(.easeOut(duration: 0.28)) { showsSpeedDisplay = true }
                }
                .transition(.move(edge: .leading))
            }
        }
    }
}

private struct SettingsRoot: View {
    let model: AppModel
    let layout: PageLayout
    let openSpeedDisplay: () -> Void
    @Environment(\.palette) private var palette
    @State private var confirmsRemoval = false

    var body: some View {
        let settings = model.settings
        VStack(spacing: 0) {
            PageHeader(title: "SETTINGS") { model.closePage() }
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    TrackedLabel(text: "VEHICLE").padding(.top, 28)
                    Hairline().padding(.top, 10)
                    vehicleRow
                    Hairline()
                    Button {
                        model.pairAgain()
                    } label: {
                        chevronRow("Pair again", height: 56)
                    }
                    .buttonStyle(.plain)
                    Hairline()
                    Button {
                        confirmsRemoval = true
                    } label: {
                        Text("Remove vehicle")
                            .font(.system(size: 17))
                            .foregroundStyle(palette.danger)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog(
                        "Remove \(model.vehicleName) from Vela?",
                        isPresented: $confirmsRemoval,
                        titleVisibility: .visible
                    ) {
                        Button("Remove vehicle", role: .destructive) { model.removeVehicle() }
                    } message: {
                        Text("Vela deletes its key from this iPhone. To remove the key from the car too, open Locks on the touchscreen.")
                    }
                    Hairline()

                    TrackedLabel(text: "DISPLAY").padding(.top, 36)
                    Hairline().padding(.top, 10)
                    segmentBlock("Speed units") {
                        Segmented(
                            options: [(SpeedUnit.mph, "MPH"), (.kmh, "km/h")],
                            selection: Binding(get: { settings.units }, set: { settings.units = $0 }),
                            accessibilityLabel: "Speed units"
                        )
                    }
                    Hairline()
                    segmentBlock("Appearance") {
                        Segmented(
                            options: [(Appearance.system, "System"), (.light, "Light"), (.dark, "Dark")],
                            selection: Binding(get: { settings.appearance }, set: { settings.appearance = $0 }),
                            accessibilityLabel: "Appearance"
                        )
                    }
                    Hairline()
                    Button(action: openSpeedDisplay) {
                        HStack {
                            Text("Speed display").font(.system(size: 17)).foregroundStyle(palette.text)
                            Spacer()
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(settings.tint.color(dark: palette.isDark))
                                    .overlay(Circle().strokeBorder(palette.line, lineWidth: 1))
                                    .frame(width: 14, height: 14)
                                Text("\(settings.tint.displayName) · \(settings.ground.displayName(dark: palette.isDark))")
                                    .font(.system(size: 15))
                                    .foregroundStyle(palette.text2)
                                Icon(.chevronRight, size: 18).foregroundStyle(palette.text3)
                            }
                        }
                        .frame(height: 60)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Hairline()
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Keep screen on while driving")
                                .font(.system(size: 17))
                                .foregroundStyle(palette.text)
                            Text("While connected to your car")
                                .font(.system(size: 15))
                                .foregroundStyle(palette.text2)
                        }
                        Spacer()
                        VelaSwitch(
                            isOn: Binding(get: { settings.keepScreenOn }, set: { settings.keepScreenOn = $0 }),
                            label: "Keep screen on while driving"
                        )
                    }
                    .frame(minHeight: 80)
                    Hairline()

                    Text("Vela \(Self.version)")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: layout.landscape ? 560 : .infinity)
        }
        .padding(layout.insets)
    }

    private var vehicleRow: some View {
        let status: (text: String, warn: Bool) = switch model.link {
        case .connected: ("Connected · Phone key", false)
        case .connecting, .idle: ("Connecting · Phone key", false)
        case .lost: ("Reconnecting · Phone key", true)
        case .bluetoothOff: ("Bluetooth is off", true)
        case .bluetoothUnauthorized: ("Bluetooth not allowed", true)
        }
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.vehicleName).font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.text)
                Text(status.text).font(.system(size: 15)).foregroundStyle(palette.text2)
            }
            Spacer()
            Circle().fill(status.warn ? palette.warn : palette.text2).frame(width: 8, height: 8)
        }
        .frame(height: 72)
        .accessibilityElement(children: .combine)
    }

    private func chevronRow(_ title: String, height: CGFloat) -> some View {
        HStack {
            Text(title).font(.system(size: 17)).foregroundStyle(palette.text)
            Spacer()
            Icon(.chevronRight, size: 18).foregroundStyle(palette.text3)
        }
        .frame(height: height)
        .contentShape(Rectangle())
    }

    private func segmentBlock(_ title: String, @ViewBuilder control: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 17)).foregroundStyle(palette.text)
            control()
        }
        .padding(.vertical, 16)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
