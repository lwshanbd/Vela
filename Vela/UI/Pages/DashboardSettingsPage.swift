import SwiftUI

/// Which modules the dashboard shows, and in what order, per orientation.
/// The preview is the real dashboard, scaled down, with the car's current
/// data; a module without data yet shows as an empty panel.
struct DashboardSettingsPage: View {
    let model: AppModel
    let layout: PageLayout
    let onBack: () -> Void
    @Environment(\.palette) private var palette
    @State private var landscapeTab = false
    @State private var previewParked = false
    @State private var dragging: DashboardModule?
    @State private var dragOffset: CGFloat = 0

    private static let rowHeight: CGFloat = 64
    private static let portraitCanvas = CGSize(width: 393, height: 852)
    private static let landscapeCanvas = CGSize(width: 852, height: 393)

    var body: some View {
        PageScaffold(layout: layout) {
            PageHeader(title: "DASHBOARD", backGlyph: .chevronLeft, backLabel: "Back to settings", onBack: onBack)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                Segmented(options: [(false, "Portrait"), (true, "Landscape")], selection: landscapeTab,
                          accessibilityLabel: "Orientation") { landscapeTab = $0 }
                    .padding(.top, 20)
                VStack(spacing: 12) {
                    preview
                    HStack(spacing: 6) {
                        modePill("Driving", selected: !previewParked) { previewParked = false }
                        modePill("Parked", selected: previewParked) { previewParked = true }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                TrackedLabel(text: "MODULES · TOP TO BOTTOM").padding(.top, 28)
                Hairline().padding(.top, 10)
                moduleList

                TrackedLabel(text: "ALERTS").padding(.top, 28)
                Hairline().padding(.top, 10)
                ForEach(DashboardAlert.allCases, id: \.self) { alert in
                    SwitchRow(title: alert.title, subtitle: alert.subtitle, isOn: model.settings.dashboard.alertOn(alert), height: 64) {
                        model.settings.dashboard.alerts[alert] = !model.settings.dashboard.alertOn(alert)
                    }
                }
                Text("Modules lower in the list wait when there is no room.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text2)
                    .padding(.top, 16)
            }
        }
    }

    // MARK: Preview

    private var preview: some View {
        let canvas = landscapeTab ? Self.landscapeCanvas : Self.portraitCanvas
        let frame = landscapeTab ? CGSize(width: 345, height: 159) : CGSize(width: 184, height: 399)
        let scale = frame.width / canvas.width
        let safe = landscapeTab
            ? EdgeInsets(top: 0, leading: 59, bottom: 21, trailing: 59)
            : EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        return DashboardComposition(model: model, size: canvas, safe: safe, forcedParked: previewParked, preview: true)
            .frame(width: canvas.width, height: canvas.height)
            .background(palette.bg)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: frame.width, height: frame.height, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: landscapeTab ? 22 : 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: landscapeTab ? 22 : 28, style: .continuous).strokeBorder(palette.line, lineWidth: 1))
            .allowsHitTesting(false)
            .accessibilityLabel("Preview")
    }

    private func modePill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? palette.bg : palette.text2)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(selected ? palette.text : palette.fill))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: Module list

    private var entries: [ModuleEntry] {
        model.settings.dashboard.entries(landscape: landscapeTab)
    }

    private func setEntries(_ new: [ModuleEntry]) {
        if landscapeTab {
            model.settings.dashboard.landscape = new
        } else {
            model.settings.dashboard.portrait = new
        }
    }

    /// Modules that are on but don't fit the preview canvas right now.
    private var noRoom: Set<DashboardModule> {
        let canvas = landscapeTab ? Self.landscapeCanvas : Self.portraitCanvas
        let safe = landscapeTab
            ? EdgeInsets(top: 0, leading: 59, bottom: 21, trailing: 59)
            : EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        let layout = DashboardLayout.make(size: canvas, safe: safe)
        let entries = entries
        let slots = DeckFit.slots(for: entries, arrangement: layout.arrangement) { _ in true }
        let chips = entries.contains { $0.isOn && $0.module.isChip }
        let power = entries.contains { $0.isOn && $0.module == .power } && !previewParked
        let budget: CGFloat
        if layout.arrangement == .column {
            let content = canvas.height - layout.insets.top - layout.insets.bottom
            budget = content - 44 - DeckFit.instrumentHeight(layout: layout, parked: previewParked, power: power, chips: chips, parkPanel: previewParked) - 16
        } else {
            budget = canvas.height - layout.insets.top - layout.insets.bottom
        }
        let all = (previewParked ? [DeckSlot.entries] : []) + slots
        let placed = DeckFit.fit(all.map { ($0, DeckFit.height(of: $0, in: layout)) }, budget: budget, gap: layout.gap)
        var result: Set<DashboardModule> = []
        for entry in entries where entry.isOn {
            let slot: DeckSlot? = switch entry.module {
            case .nav: .nav
            case .map: .map
            case .climate: .climate
            case .media: .media
            case .range, .temps, .heading: layout.arrangement == .row ? .chips : nil
            case .power: nil
            }
            if let slot, !placed.contains(slot) { result.insert(entry.module) }
        }
        return result
    }

    private var moduleList: some View {
        let entries = entries
        let noRoom = noRoom
        return VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                moduleRow(entry, noRoom: noRoom.contains(entry.module), index: index, count: entries.count)
                    .offset(y: dragging == entry.module ? dragOffset : 0)
                    .zIndex(dragging == entry.module ? 1 : 0)
            }
        }
    }

    private func moduleRow(_ entry: ModuleEntry, noRoom: Bool, index: Int, count: Int) -> some View {
        HStack(spacing: 12) {
            Icon(.grip, size: 20)
                .foregroundStyle(palette.text3)
                .frame(width: 32, height: 44, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            dragging = entry.module
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            let steps = Int((value.translation.height / Self.rowHeight).rounded())
                            let target = min(max(0, index + steps), count - 1)
                            var reordered = entries
                            let moved = reordered.remove(at: index)
                            reordered.insert(moved, at: target)
                            withAnimation(.easeOut(duration: 0.2)) {
                                setEntries(reordered)
                                dragging = nil
                                dragOffset = 0
                            }
                        }
                )
                .accessibilityLabel("Reorder \(entry.module.title)")
                .accessibilityAdjustableAction { direction in
                    let target = direction == .increment ? min(index + 1, count - 1) : max(index - 1, 0)
                    var reordered = entries
                    reordered.swapAt(index, target)
                    setEntries(reordered)
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(entry.module.title).font(.system(size: 17)).foregroundStyle(palette.text)
                    if noRoom {
                        Text("No room")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.44)
                            .foregroundStyle(palette.text2)
                            .padding(.horizontal, 7)
                            .frame(height: 20)
                            .background(Capsule().fill(palette.fill))
                    }
                }
                Text(entry.module.subtitle).font(.system(size: 13)).foregroundStyle(palette.text2)
            }
            .padding(.vertical, 10)
            Spacer(minLength: 0)
            VelaSwitch(isOn: entry.isOn, label: entry.module.title) {
                var updated = entries
                updated[index].isOn.toggle()
                setEntries(updated)
            }
        }
        .frame(height: Self.rowHeight)
        .background(palette.bg)
        .overlay(alignment: .bottom) { Hairline() }
    }
}
