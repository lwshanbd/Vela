import SwiftUI

/// The driving screen. Portrait and landscape (and the iPhone Duo's displays)
/// are compositions of the same instrument and modules, chosen by the current
/// geometry. All state lives in `AppModel`, so switching composition never
/// touches the session.
struct DashboardView: View {
    let model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.fullScreenSize
            let landscape = size.width > size.height
            ZStack {
                palette.bg.ignoresSafeArea()
                DashboardComposition(model: model, size: size, safe: proxy.safeAreaInsets)
                    .id(landscape)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.15), value: landscape)
            .animation(.easeInOut(duration: 0.15), value: model.isParked)
            .ignoresSafeArea()
        }
    }
}

/// One rendering of the dashboard at a given size. The settings preview uses
/// it with a forced driving/parked state.
struct DashboardComposition: View {
    let model: AppModel
    let size: CGSize
    let safe: EdgeInsets
    var forcedParked: Bool?
    var preview = false

    var body: some View {
        let layout = DashboardLayout.make(size: size, safe: safe)
        let context = DashContext(
            model: model,
            layout: layout,
            landscape: size.width > size.height,
            parked: forcedParked ?? model.isParked,
            live: preview || model.isLive,
            preview: preview
        )
        switch layout.arrangement {
        case .column: ColumnDashboard(context: context, size: size)
        case .row: RowDashboard(context: context, size: size)
        }
    }
}

/// Speed above, deck below.
private struct ColumnDashboard: View {
    let context: DashContext
    let size: CGSize

    var body: some View {
        let layout = context.layout
        let contentHeight = size.height - layout.insets.top - layout.insets.bottom
        let instrument = DeckFit.instrumentHeight(
            layout: layout, parked: context.parked, power: context.showsPower,
            chips: !context.chipModules.isEmpty && context.live, parkPanel: context.showsParkPanel
        )
        let slots = orderedSlots(context)
        let budget = contentHeight - 44 - instrument - 16
        let placedSet = DeckFit.fit(slots.map { ($0, DeckFit.height(of: $0, in: layout)) }, budget: budget, gap: layout.gap)
        let placed = slots.filter(placedSet.contains)
        VStack(spacing: 0) {
            StatusHeader(context: context)
            InstrumentView(context: context)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: layout.gap) {
                if context.showsParkPanel {
                    ParkPanel(context: context)
                }
                DeckStack(context: context, slots: placed)
            }
            .frame(maxWidth: layout.deckMaxWidth ?? .infinity)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
        .padding(layout.insets)
    }
}

/// Instrument on the leading side, deck on the trailing side.
private struct RowDashboard: View {
    let context: DashContext
    let size: CGSize

    var body: some View {
        let layout = context.layout
        let contentHeight = size.height - layout.insets.top - layout.insets.bottom
        let slots = orderedSlots(context)
        let placedSet = DeckFit.fit(slots.map { ($0, DeckFit.height(of: $0, in: layout)) }, budget: contentHeight, gap: layout.gap)
        let placed = slots.filter(placedSet.contains)
        let inner = size.width - layout.insets.leading - layout.insets.trailing
        let hasDeck = !placed.isEmpty
        let dividerWidth: CGFloat = layout.divider && hasDeck ? 1 : 0
        let instrumentWidth = hasDeck
            ? (inner - dividerWidth) * layout.instrumentShare / (layout.instrumentShare + 1)
            : inner
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                StatusHeader(context: context)
                InstrumentView(context: context)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.trailing, hasDeck ? layout.instrumentTrailingPad : 0)
            .frame(width: instrumentWidth)

            if hasDeck {
                if layout.divider {
                    Hairline(vertical: true).padding(.vertical, 36)
                }
                DeckStack(context: context, slots: placed)
                    .frame(maxWidth: layout.deckMaxWidth ?? .infinity)
                    .padding(.leading, layout.deckLeadingPad)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(layout.insets)
    }
}

/// Deck slots in order, dimmed and inert while not live.
private struct DeckStack: View {
    let context: DashContext
    let slots: [DeckSlot]

    var body: some View {
        VStack(spacing: context.layout.gap) {
            ForEach(slots, id: \.self) { slot in
                switch slot {
                case .entries: EntriesPanel(context: context)
                case .chips: ChipRow(context: context).frame(maxWidth: .infinity, alignment: .leading)
                case .nav: NavPanel(context: context)
                case .map: MapPanel(context: context)
                case .climate: ClimatePanel(context: context)
                case .media: MediaPanel(context: context)
                }
            }
        }
        .opacity(context.live ? 1 : 0.28)
        .allowsHitTesting(context.live && !context.preview)
        .animation(.easeInOut(duration: 0.2), value: slots)
    }
}

/// Entries first when parked, then modules in the user's order.
@MainActor
private func orderedSlots(_ context: DashContext) -> [DeckSlot] {
    let modules = DeckFit.slots(for: context.entries, arrangement: context.layout.arrangement) { module in
        context.preview || context.hasData(module)
    }
    return (context.showsParkPanel ? [.entries] : []) + modules
}
