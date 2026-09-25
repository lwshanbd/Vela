import SwiftUI

struct SettingsPage: View {
    let model: AppModel
    let layout: PageLayout
    @State private var subpage: Subpage?

    enum Subpage { case dashboard, speedDisplay }

    var body: some View {
        ZStack {
            switch subpage {
            case .dashboard?:
                DashboardSettingsPage(model: model, layout: layout) { show(nil) }
                    .transition(.move(edge: .trailing))
            case .speedDisplay?:
                SpeedDisplayPage(model: model, layout: layout) { show(nil) }
                    .transition(.move(edge: .trailing))
            case nil:
                SettingsRoot(model: model, layout: layout, open: show)
                    .transition(.move(edge: .leading))
            }
        }
    }

    private func show(_ page: Subpage?) {
        withAnimation(.easeOut(duration: 0.28)) { subpage = page }
    }
}

private struct SettingsRoot: View {
    let model: AppModel
    let layout: PageLayout
    let open: (SettingsPage.Subpage) -> Void
    @Environment(\.palette) private var palette
    @State private var confirmsRemoval = false

    var body: some View {
        let settings = model.settings
        PageScaffold(layout: layout) {
            PageHeader(title: "SETTINGS", onBack: model.closePage)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                TrackedLabel(text: "VEHICLE").padding(.top, 28)
                Hairline().padding(.top, 10)
                vehicleRow
                Hairline()
                Button { model.pairAgain() } label: { chevronRow("Pair again", detail: nil, height: 56) }
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
                .confirmationDialog("Remove \(model.vehicleName) from Vela?", isPresented: $confirmsRemoval, titleVisibility: .visible) {
                    Button("Remove vehicle", role: .destructive) { model.removeVehicle() }
                } message: {
                    Text("Vela deletes its key from this iPhone. To remove the key from the car too, open Locks on the touchscreen.")
                }
                Hairline()

                TrackedLabel(text: "DISPLAY").padding(.top, 36)
                Hairline().padding(.top, 10)
                segmentBlock("Speed units") {
                    Segmented(options: [(SpeedUnit.mph, "MPH"), (.kmh, "km/h")], selection: settings.units,
                              accessibilityLabel: "Speed units") { settings.units = $0 }
                }
                Hairline()
                segmentBlock("Appearance") {
                    Segmented(options: [(Appearance.system, "System"), (.light, "Light"), (.dark, "Dark")],
                              selection: settings.appearance, accessibilityLabel: "Appearance") { settings.appearance = $0 }
                }
                Hairline()
                Button { open(.dashboard) } label: {
                    chevronRow("Dashboard", detail: "\(settings.dashboard.enabledCount) modules", height: 60)
                }
                .buttonStyle(.plain)
                Hairline()
                Button { open(.speedDisplay) } label: {
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
                SwitchRow(
                    title: "Keep screen on while driving", subtitle: "While connected to your car",
                    isOn: settings.keepScreenOn, height: 80
                ) { settings.keepScreenOn.toggle() }

                Text("Vela \(Self.version)")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
            }
        }
    }

    private var vehicleRow: some View {
        let status: (text: String, warn: Bool) = switch model.link {
        case .connected: ("Connected · Phone key", false)
        case .connecting, .idle: ("Connecting · Phone key", false)
        case .asleep: ("Asleep · Phone key", false)
        case .lost: ("Reconnecting · Phone key", true)
        case .bluetoothOff: ("Bluetooth is off", true)
        case .bluetoothUnauthorized: ("Bluetooth access is off", true)
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

    private func chevronRow(_ title: String, detail: String?, height: CGFloat) -> some View {
        HStack {
            Text(title).font(.system(size: 17)).foregroundStyle(palette.text)
            Spacer()
            if let detail {
                Text(detail).font(.system(size: 15)).foregroundStyle(palette.text2)
            }
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
