import SwiftUI

/// Hosts a page over the dashboard: rises from the bottom, follows a
/// downward swipe, and closes past a threshold. Any touch counts as activity
/// for the 10 s auto-close.
struct PageContainer: View {
    let model: AppModel
    let page: DashboardPage
    @Environment(\.palette) private var palette
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.fullScreenSize
            let layout = PageLayout(size: size, safe: proxy.safeAreaInsets)
            Group {
                switch page {
                case .music: MusicPage(model: model, layout: layout)
                case .climate: ClimatePage(model: model, layout: layout)
                case .settings: SettingsPage(model: model, layout: layout)
                case .controls: ControlsPage(model: model, layout: layout)
                case .chargers: ChargersPage(model: model, layout: layout)
                case .vehicle: VehiclePage(model: model, layout: layout)
                case .charging: ChargingPage(model: model, layout: layout)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.bg)
            .offset(y: dragOffset)
            .simultaneousGesture(TapGesture().onEnded { model.notePageInteraction() })
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        model.notePageInteraction()
                        // Only vertical drags starting near the top move the
                        // sheet, so sliders and lists keep their own gestures.
                        guard value.startLocation.y < min(160, size.height * 0.2),
                              abs(value.translation.height) > abs(value.translation.width)
                        else { return }
                        dragOffset = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        if dragOffset > 120 || (dragOffset > 0 && value.predictedEndTranslation.height > 320) {
                            model.closePage()
                        }
                        withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                    }
            )
            .ignoresSafeArea()
        }
    }
}

/// Insets shared by every page: 28 pt sides in portrait, symmetric
/// island-side insets in landscape.
struct PageLayout {
    let size: CGSize
    let safe: EdgeInsets

    var landscape: Bool { size.width > size.height }

    var insets: EdgeInsets {
        if landscape {
            let side = max(safe.leading, safe.trailing, 28)
            return EdgeInsets(top: 28, leading: side, bottom: max(safe.bottom + 10, 28), trailing: side)
        }
        return EdgeInsets(top: max(safe.top, 20), leading: 28, bottom: max(safe.bottom + 10, 20), trailing: 28)
    }

    var contentWidth: CGFloat { size.width - insets.leading - insets.trailing }
    var contentHeight: CGFloat { size.height - insets.top - insets.bottom }
}

extension GeometryProxy {
    /// The whole screen in points, safe areas included. The design's size
    /// rules (speed = 0.51 × width …) are written against full screen points.
    var fullScreenSize: CGSize {
        CGSize(
            width: size.width + safeAreaInsets.leading + safeAreaInsets.trailing,
            height: size.height + safeAreaInsets.top + safeAreaInsets.bottom
        )
    }
}

/// Scrollable page body with the header pinned above it.
struct PageScaffold<Header: View, Content: View>: View {
    let layout: PageLayout
    var maxWidth: CGFloat = 560
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            header()
            ScrollView(.vertical) {
                content()
                    .frame(maxWidth: maxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .padding(layout.insets)
    }
}
