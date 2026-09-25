import SwiftUI

@main
struct VelaApp: App {
    /// Owned by the App, not a view: the BLE session outlives rotation and
    /// every view rebuild.
    #if DEBUG
    @State private var model = AppModel.fromLaunchArguments()
    #else
    @State private var model = AppModel()
    #endif

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        let scheme = resolvedScheme
        // Setup screens use the pure ground; the Speed display ground choice
        // is for the driving screens.
        let ground = model.onboarding == nil ? model.settings.ground : .pure
        let palette = Palette.make(dark: scheme == .dark, ground: ground)
        ZStack {
            palette.bg.ignoresSafeArea()
            if let step = model.onboarding {
                OnboardingView(model: model, step: step)
                    .transition(.opacity)
            } else {
                DashboardView(model: model)
                if let page = model.page {
                    PageContainer(model: model, page: page)
                        .transition(.move(edge: .bottom))
                        .zIndex(1)
                }
            }
        }
        .animation(.easeOut(duration: 0.28), value: model.page)
        .animation(.easeInOut(duration: 0.2), value: model.onboarding == nil)
        .environment(\.palette, palette)
        .preferredColorScheme(model.settings.appearance == .system ? nil : scheme)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase, initial: true) { _, phase in
            model.sceneDidChange(to: phase)
        }
        .onChange(of: model.shouldKeepScreenAwake, initial: true) { _, awake in
            // The only place the idle timer is touched.
            UIApplication.shared.isIdleTimerDisabled = awake
        }
        #if DEBUG
        .task { await Self.applyDebugOrientation() }
        #endif
    }

    #if DEBUG
    /// `-VelaLandscape` rotates the simulator to landscape after launch. DEBUG only.
    private static func applyDebugOrientation() async {
        guard ProcessInfo.processInfo.arguments.contains("-VelaLandscape") else { return }
        try? await Task.sleep(for: .milliseconds(500))
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    }
    #endif

    private var resolvedScheme: ColorScheme {
        switch model.settings.appearance {
        case .system: systemScheme
        case .light: .light
        case .dark: .dark
        }
    }
}
