import SwiftUI

/// Sizes and arrangement of the dashboard for one screen shape. Chosen from
/// the scene's size, never from the device model: phones have a short side
/// under 460 pt, the iPhone Duo outer display 466 pt, its inner display 626 pt.
struct DashboardLayout: Equatable {
    enum Arrangement { case column, row }

    var arrangement: Arrangement
    var insets: EdgeInsets
    var speed: CGFloat
    var parkedSpeed: CGFloat
    /// Row only: instrument width relative to the deck (deck = 1).
    var instrumentShare: CGFloat = 1
    var instrumentTrailingPad: CGFloat = 0
    var deckLeadingPad: CGFloat = 0
    var deckMaxWidth: CGFloat?
    var divider = false
    var unitSize: CGFloat
    var rowSize: CGFloat
    var climateButton: CGFloat
    var climateFont: CGFloat
    var playSize: CGFloat
    var skipSize: CGFloat
    var transportGap: CGFloat
    var entriesHeight: CGFloat
    var navHeight: CGFloat
    var mapHeight: CGFloat
    var gap: CGFloat = 12

    var climateHeight: CGFloat { climateButton + 16 }
    var mediaHeight: CGFloat { playSize + 56 }
    var chipsHeight: CGFloat { 40 }

    static func make(size: CGSize, safe: EdgeInsets) -> DashboardLayout {
        let landscape = size.width > size.height
        let short = min(size.width, size.height)
        func inset(top: CGFloat, side: CGFloat, bottom: CGFloat) -> EdgeInsets {
            EdgeInsets(
                top: max(safe.top, top),
                leading: max(safe.leading, safe.trailing, side),
                bottom: max(safe.bottom + 10, bottom),
                trailing: max(safe.leading, safe.trailing, side)
            )
        }
        switch (short, landscape) {
        case (..<460, false):
            // Phone portrait. Speed = min(0.51 × width, 0.235 × height), ≥ 150 pt.
            let speed = max(150, min(0.51 * size.width, 0.235 * size.height))
            let compact = size.height < 700
            return DashboardLayout(
                arrangement: .column, insets: inset(top: 20, side: 28, bottom: 20),
                speed: speed, parkedSpeed: (speed * 0.64).rounded(),
                unitSize: 15, rowSize: 26,
                climateButton: compact ? 64 : 72, climateFont: compact ? 44 : 50,
                playSize: compact ? 56 : 64, skipSize: compact ? 48 : 56, transportGap: compact ? 30 : 40,
                entriesHeight: 68, navHeight: 68, mapHeight: compact ? 120 : 150
            )
        case (..<460, true):
            // Phone landscape. Speed = 0.45 × height.
            return DashboardLayout(
                arrangement: .row, insets: inset(top: 28, side: 28, bottom: 28),
                speed: (0.45 * size.height).rounded(), parkedSpeed: (0.285 * size.height).rounded(),
                instrumentShare: 1.08, instrumentTrailingPad: 28, deckLeadingPad: 8,
                unitSize: 14, rowSize: 24,
                climateButton: 60, climateFont: 42, playSize: 56, skipSize: 52, transportGap: 32,
                entriesHeight: 64, navHeight: 64, mapHeight: 140
            )
        case (..<600, false):
            // iPhone Duo, closed, outer display.
            return DashboardLayout(
                arrangement: .column, insets: inset(top: 24, side: 28, bottom: 28),
                speed: 220, parkedSpeed: 128, deckMaxWidth: 410,
                unitSize: 15, rowSize: 26,
                climateButton: 72, climateFont: 50, playSize: 64, skipSize: 56, transportGap: 40,
                entriesHeight: 68, navHeight: 68, mapHeight: 150
            )
        case (..<600, true):
            // iPhone Duo, closed and rotated.
            return DashboardLayout(
                arrangement: .row, insets: inset(top: 28, side: 28, bottom: 28),
                speed: 172, parkedSpeed: 112,
                instrumentShare: 1.2, instrumentTrailingPad: 16, deckLeadingPad: 20, deckMaxWidth: 300, divider: true,
                unitSize: 14, rowSize: 24,
                climateButton: 60, climateFont: 42, playSize: 56, skipSize: 52, transportGap: 32,
                entriesHeight: 64, navHeight: 64, mapHeight: 140
            )
        case (_, true):
            // iPhone Duo, open, inner display.
            return DashboardLayout(
                arrangement: .row, insets: inset(top: 32, side: 40, bottom: 32),
                speed: 256, parkedSpeed: 150,
                instrumentShare: 1.5, instrumentTrailingPad: 36, deckLeadingPad: 36, deckMaxWidth: 340, divider: true,
                unitSize: 15, rowSize: 26,
                climateButton: 72, climateFont: 50, playSize: 64, skipSize: 56, transportGap: 40,
                entriesHeight: 68, navHeight: 68, mapHeight: 150
            )
        case (_, false):
            // iPhone Duo, open and rotated.
            return DashboardLayout(
                arrangement: .column, insets: inset(top: 40, side: 32, bottom: 40),
                speed: 280, parkedSpeed: 150, deckMaxWidth: 460,
                unitSize: 15, rowSize: 26,
                climateButton: 76, climateFont: 54, playSize: 64, skipSize: 56, transportGap: 40,
                entriesHeight: 68, navHeight: 68, mapHeight: 150
            )
        }
    }
}

/// A slot on the deck, in layout order.
enum DeckSlot: Hashable {
    case entries, chips, nav, map, climate, media
}

enum DeckFit {
    /// Places slots in order while they fit; a slot that doesn't fit waits
    /// and later, smaller ones may still take the space ("no squeezing").
    static func fit(_ slots: [(slot: DeckSlot, height: CGFloat)], budget: CGFloat, gap: CGFloat) -> Set<DeckSlot> {
        var used: CGFloat = 0
        var placed: Set<DeckSlot> = []
        for (slot, height) in slots {
            let need = placed.isEmpty ? height : used + gap + height
            if need <= budget {
                used = need
                placed.insert(slot)
            }
        }
        return placed
    }

    /// The deck slots for a module list, in its order. Chips sit where the
    /// first chip module is in a row layout; in a column they live under the
    /// gear, so they are not deck slots.
    static func slots(
        for entries: [ModuleEntry],
        arrangement: DashboardLayout.Arrangement,
        isAvailable: (DashboardModule) -> Bool
    ) -> [DeckSlot] {
        var result: [DeckSlot] = []
        for entry in entries where entry.isOn && isAvailable(entry.module) {
            switch entry.module {
            case .range, .temps, .heading:
                if arrangement == .row, !result.contains(.chips) { result.append(.chips) }
            case .nav: result.append(.nav)
            case .map: result.append(.map)
            case .climate: result.append(.climate)
            case .media: result.append(.media)
            case .power: break
            }
        }
        return result
    }

    static func height(of slot: DeckSlot, in layout: DashboardLayout) -> CGFloat {
        switch slot {
        case .entries: layout.entriesHeight
        case .chips: layout.chipsHeight
        case .nav: layout.navHeight
        case .map: layout.mapHeight
        case .climate: layout.climateHeight
        case .media: layout.mediaHeight
        }
    }

    /// Height the instrument column needs above the deck (column layouts).
    static func instrumentHeight(
        layout: DashboardLayout, parked: Bool, power: Bool, chips: Bool, parkPanel: Bool
    ) -> CGFloat {
        let speed = (parked ? layout.parkedSpeed : layout.speed) * 0.86
        return speed + 30 + (power ? 40 : 0) + (parked ? 50 : 62) + (chips ? 64 : 0) + 12 + (parkPanel ? 104 : 0)
    }
}
