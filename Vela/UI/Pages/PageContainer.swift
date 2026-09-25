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
            let safe = proxy.safeAreaInsets
            let size = proxy.fullScreenSize
            let landscape = size.width > size.height
            let layout = PageLayout(size: size, safe: safe, landscape: landscape)
            Group {
                switch page {
                case .music: MusicPage(model: model, layout: layout)
                case .climate: ClimatePage(model: model, layout: layout)
                case .settings: SettingsPage(model: model, layout: layout)
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
                        // Only vertical drags from the upper part move the sheet,
                        // so sliders and lists below keep their own gestures.
                        guard value.startLocation.y < size.height * 0.45,
                              abs(value.translation.height) > abs(value.translation.width)
                        else { return }
                        dragOffset = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        if dragOffset > 120 || value.predictedEndTranslation.height > 320, dragOffset > 0 {
                            model.closePage()
                        }
                        withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                    }
            )
            .ignoresSafeArea()
        }
    }
}

/// Insets shared by every page: 24 pt sides and the safe area in portrait,
/// symmetric island-side insets in landscape.
struct PageLayout {
    let size: CGSize
    let safe: EdgeInsets
    let landscape: Bool

    var insets: EdgeInsets {
        if landscape {
            let side = max(safe.leading, safe.trailing, 24)
            return EdgeInsets(top: 16, leading: side, bottom: max(safe.bottom, 16), trailing: side)
        }
        return EdgeInsets(top: max(safe.top, 20), leading: 24, bottom: max(safe.bottom, 16), trailing: 24)
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
