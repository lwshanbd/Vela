import SwiftUI

/// The driving screen. Portrait and landscape are separate compositions of
/// the same instrument and modules, chosen by the current geometry. All state
/// lives in `AppModel`, so switching composition never touches the session.
struct DashboardView: View {
    let model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let safe = proxy.safeAreaInsets
            let size = proxy.fullScreenSize
            let landscape = size.width > size.height
            ZStack {
                palette.bg.ignoresSafeArea()
                Group {
                    if landscape {
                        LandscapeDashboard(model: model, size: size, safe: safe)
                    } else {
                        PortraitDashboard(model: model, size: size, safe: safe)
                    }
                }
                .id(landscape)
                .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.15), value: landscape)
            .ignoresSafeArea()
        }
    }
}

/// Deck opacity and hit-testing: dimmed and inert while not live.
private struct DeckState: ViewModifier {
    let live: Bool
    func body(content: Content) -> some View {
        content
            .opacity(live ? 1 : 0.28)
            .allowsHitTesting(live)
            .animation(.easeInOut(duration: 0.2), value: live)
    }
}

struct PortraitDashboard: View {
    let model: AppModel
    let size: CGSize
    let safe: EdgeInsets

    var body: some View {
        // Speed = min(0.51 × width, 0.235 × height), never below 150 pt.
        let speed = max(150, min(0.51 * size.width, 0.235 * size.height))
        // Below 700 pt tall the deck drops to 64 pt controls and tighter gaps.
        let compact = size.height < 700
        let showClimate = model.hasClimate
        let showMedia = model.hasMedia
        VStack(spacing: 0) {
            StatusHeader(model: model)
            InstrumentView(model: model, metrics: .portrait(speedSize: speed))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showClimate || showMedia {
                Hairline()
                VStack(spacing: compact ? 25.5 : 34) {
                    if showClimate {
                        ClimateModule(
                            model: model,
                            buttonSize: compact ? 64 : 76, iconSize: compact ? 26 : 28,
                            fontSize: compact ? 46 : 54, labelMinWidth: compact ? 110 : 132
                        )
                    }
                    if showMedia {
                        PortraitMediaModule(model: model, compact: compact)
                    }
                }
                .padding(.top, compact ? 21 : 28)
                .padding(.bottom, compact ? 6 : 10)
                .modifier(DeckState(live: model.isLive))
            }
        }
        .padding(.top, max(safe.top, 20))
        .padding(.bottom, max(safe.bottom, 16))
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: showClimate)
        .animation(.easeInOut(duration: 0.2), value: showMedia)
    }
}

struct LandscapeDashboard: View {
    let model: AppModel
    let size: CGSize
    let safe: EdgeInsets

    var body: some View {
        // Same inset on both sides whichever way the island faces, so nothing
        // shifts when the phone is flipped.
        let side = max(safe.leading, safe.trailing, 24)
        let speed = 0.45 * size.height
        let showClimate = model.hasClimate
        let showMedia = model.hasMedia
        let hasDeck = showClimate || showMedia
        let inner = size.width - 2 * side
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                StatusHeader(model: model)
                InstrumentView(model: model, metrics: .landscape(speedSize: speed))
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.trailing, hasDeck ? 28 : 0)
            .frame(width: hasDeck ? (inner - 1) * 1.12 / 2.12 : inner)

            if hasDeck {
                Hairline(vertical: true)
                    .padding(.top, 36)
                    .padding(.bottom, 32)
                VStack(spacing: 22) {
                    if showMedia {
                        LandscapeMediaModule(model: model)
                    }
                    if showMedia, showClimate {
                        Hairline()
                    }
                    if showClimate {
                        ClimateModule(model: model, buttonSize: 64, iconSize: 26, fontSize: 46, labelMinWidth: 110)
                    }
                }
                .padding(.leading, 36)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .modifier(DeckState(live: model.isLive))
            }
        }
        .padding(.horizontal, side)
        .padding(.top, 16)
        .padding(.bottom, max(safe.bottom, 16))
    }
}
