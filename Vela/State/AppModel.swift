import Foundation
import Observation
import SwiftUI
import UIKit

enum OnboardingStep: Equatable {
    case welcome
    case finding
    case chooseCar
    /// `expectedLocalName` is set when the user picked a car from the nearby
    /// list; the VIN they type must hash to it.
    case enterVIN(expectedLocalName: String?)
    case addKey(VehicleIdentity)
    case confirmInCar(VehicleIdentity)
    case paired(VehicleIdentity)
}

enum DashboardPage: Equatable {
    case music
    case climate
    case settings
}

/// Root application state. Converts vehicle readings into what the screens
/// show and turns user intents into vehicle commands. Views never talk to
/// TeslaBLE directly.
@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let connection: VehicleConnection
    let pairing: PairingSession
    let scanner = NearbyTeslaScanner()
    private let identityStore: VehicleIdentityStore

    /// Non-nil while the onboarding / pairing flow is on screen.
    var onboarding: OnboardingStep?
    private var onboardingHistory: [OnboardingStep] = []
    /// True when pairing was started from Settings ("Pair again"): cancel
    /// goes back to the dashboard instead of the start of setup.
    private(set) var isRepairing = false

    var page: DashboardPage? {
        didSet {
            lastPageInteraction = .now
            connection.detail = switch page {
            case .music: .music
            case .climate: .climate
            default: .none
            }
        }
    }

    private var lastPageInteraction = Date.now
    private var pageIdleTask: Task<Void, Never>?
    private var isSceneActive = false
    private var backgroundStop: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    /// Setpoints the user just chose, shown until the car reports them.
    private var climateDraft: (driverC: Double, passengerC: Double, until: Date)?
    private var climateSend: Task<Void, Never>?
    #if DEBUG
    fileprivate(set) var usesFixtures = false
    #endif

    init(settings: AppSettings = AppSettings(), identityStore: VehicleIdentityStore = VehicleIdentityStore()) {
        self.settings = settings
        self.identityStore = identityStore
        connection = VehicleConnection(keyStore: identityStore.keyStore)
        pairing = PairingSession(store: identityStore)
        identity = identityStore.paired
        if identity == nil {
            onboarding = .welcome
        }
    }

    private(set) var identity: VehicleIdentity?
    var vehicleName: String { identity?.modelName ?? "Tesla" }

    // MARK: - Scene lifecycle

    func sceneDidChange(to phase: ScenePhase) {
        switch phase {
        case .active:
            isSceneActive = true
            backgroundStop?.cancel()
            backgroundStop = nil
            endBackgroundTask()
            startConnectionIfPossible()
            startPageIdleWatch()
        case .background:
            isSceneActive = false
            scheduleBackgroundStop()
        default:
            // Inactive (Control Center, app switcher peek): keep the session.
            break
        }
    }

    private func startConnectionIfPossible() {
        guard isSceneActive, onboarding == nil, let identity else { return }
        #if DEBUG
        guard !usesFixtures else { return }
        #endif
        connection.start(identity)
    }

    /// A short trip to another app (Maps, Messages) keeps the session;
    /// staying away ends it cleanly so the car isn't held awake.
    private func scheduleBackgroundStop() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "vela.disconnect") { [weak self] in
            Task { @MainActor in
                await self?.connection.stop()
                self?.endBackgroundTask()
            }
        }
        backgroundStop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self else { return }
            await self.connection.stop()
            self.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    // MARK: - Screen awake

    /// The single rule for `isIdleTimerDisabled`: the user wants it, the app
    /// is in front on the dashboard, and the car is (or was just) connected.
    var shouldKeepScreenAwake: Bool {
        guard settings.keepScreenOn, isSceneActive, onboarding == nil else { return false }
        return connection.link == .connected || connection.link == .lost
    }

    // MARK: - Dashboard display

    var link: LinkState { connection.link }
    var isLive: Bool { connection.link == .connected }

    /// Speed in the chosen unit, from the car's last drive response. `nil`
    /// means the car sent no speed and isn't in Park, so there's nothing
    /// truthful to show.
    var displaySpeed: Int? {
        guard let drive = connection.readings.drive else { return nil }
        guard let mph = drive.speedMph else {
            return drive.gear == .park ? 0 : nil
        }
        let value = settings.units == .mph ? mph : mph * 1.609344
        return Int(value.rounded())
    }

    var gear: Gear? { connection.readings.drive?.gear }
    var batteryLevel: Int? { connection.readings.batteryLevel }
    var unitLabel: String { settings.units == .mph ? "MPH" : "KM/H" }

    /// Settings only when parked: at 0 or when not live.
    var showsSettingsButton: Bool {
        !isLive || (displaySpeed ?? 0) == 0
    }

    var isInGear: Bool {
        guard let gear else { return false }
        return gear != .park
    }

    // MARK: - Pages

    func open(_ page: DashboardPage) {
        self.page = page
    }

    func closePage() {
        page = nil
    }

    func notePageInteraction() {
        lastPageInteraction = .now
    }

    /// Pages close by themselves after 10 s idle while the car is in gear.
    private func startPageIdleWatch() {
        pageIdleTask?.cancel()
        pageIdleTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if self.page != nil, self.isInGear,
                   Date.now.timeIntervalSince(self.lastPageInteraction) > 10
                {
                    self.page = nil
                }
            }
        }
    }

    // MARK: - Climate

    var climate: ClimateReading? { connection.readings.climate }
    var hasClimate: Bool { climate != nil }

    var driverSetpointC: Double? {
        if let draft = activeDraft { return draft.driverC }
        return climate?.driverSetpointC
    }

    var passengerSetpointC: Double? {
        if let draft = activeDraft { return draft.passengerC }
        return climate?.passengerSetpointC
    }

    private var activeDraft: (driverC: Double, passengerC: Double, until: Date)? {
        guard let draft = climateDraft, draft.until > .now else { return nil }
        return draft
    }

    func temperatureLabel(_ celsius: Double?) -> String {
        guard let celsius else { return "–" }
        switch settings.units {
        case .mph:
            return "\(Int((celsius * 9 / 5 + 32).rounded()))°"
        case .kmh:
            let half = (celsius * 2).rounded() / 2
            return half == half.rounded() ? "\(Int(half))°" : String(format: "%.1f°", half)
        }
    }

    /// One tap: 1 °F, or 0.5 °C. Tesla accepts 15–28 °C.
    private func stepped(_ celsius: Double, by direction: Int) -> Double {
        let result: Double
        switch settings.units {
        case .mph:
            let fahrenheit = (celsius * 9 / 5 + 32).rounded() + Double(direction)
            result = (fahrenheit - 32) * 5 / 9
        case .kmh:
            result = (celsius * 2).rounded() / 2 + 0.5 * Double(direction)
        }
        return min(28, max(15, result))
    }

    func adjustDriverTemperature(by direction: Int) {
        guard let driver = driverSetpointC, let passenger = passengerSetpointC else { return }
        let newDriver = stepped(driver, by: direction)
        let newPassenger = settings.syncClimateZones ? newDriver : passenger
        setDraft(driverC: newDriver, passengerC: newPassenger)
    }

    func adjustPassengerTemperature(by direction: Int) {
        guard let driver = driverSetpointC, let passenger = passengerSetpointC else { return }
        settings.syncClimateZones = false
        setDraft(driverC: driver, passengerC: stepped(passenger, by: direction))
    }

    func setSyncZones(_ sync: Bool) {
        settings.syncClimateZones = sync
        if sync, let driver = driverSetpointC, let passenger = passengerSetpointC, driver != passenger {
            setDraft(driverC: driver, passengerC: driver)
        }
    }

    /// Shows the new setpoint at once, then sends it after taps settle so a
    /// run of presses becomes one BLE command.
    private func setDraft(driverC: Double, passengerC: Double) {
        notePageInteraction()
        climateDraft = (driverC, passengerC, .now.addingTimeInterval(8))
        climateSend?.cancel()
        climateSend = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self else { return }
            let ok = await self.connection.setTemperatures(driverC: driverC, passengerC: passengerC)
            // The refresh inside the command now carries the car's value.
            if !ok || self.climateDraft?.driverC == driverC {
                self.climateDraft = nil
            }
        }
    }

    func setClimate(on: Bool) {
        notePageInteraction()
        Task { await connection.setClimate(on: on) }
    }

    // MARK: - Media

    var media: MediaReading? { connection.readings.media }
    var hasMedia: Bool { media?.hasTrack == true }

    func mediaAction(_ action: VehicleConnection.MediaAction) {
        notePageInteraction()
        Task { await connection.media(action) }
    }

    // MARK: - Onboarding & pairing

    func advance(to step: OnboardingStep) {
        if let current = onboarding {
            onboardingHistory.append(current)
        }
        onboarding = step
        onStepChange(step)
    }

    func goBack() {
        guard let previous = onboardingHistory.popLast() else {
            if isRepairing { finishRepairingCancelled() }
            return
        }
        onboarding = previous
        onStepChange(previous)
    }

    /// Cancel on "Confirm in your car" returns to choosing a car.
    func cancelPairing() {
        pairing.cancel()
        if isRepairing {
            finishRepairingCancelled()
            return
        }
        onboardingHistory.removeAll { if case .welcome = $0 { false } else { true } }
        onboardingHistory.append(.finding)
        onboarding = .chooseCar
        onStepChange(.chooseCar)
    }

    func startPairing(_ identity: VehicleIdentity) {
        advance(to: .confirmInCar(identity))
        pairing.start(identity)
    }

    func pairingSucceeded(_ identity: VehicleIdentity) {
        self.identity = identity
        onboardingHistory.removeAll()
        onboarding = .paired(identity)
    }

    func openDashboard() {
        onboarding = nil
        onboardingHistory.removeAll()
        isRepairing = false
        pairing.cancel()
        page = nil
        startConnectionIfPossible()
    }

    func pairAgain() {
        guard let identity else { return }
        isRepairing = true
        page = nil
        onboardingHistory.removeAll()
        Task {
            // Pairing needs the radio and the car's attention to itself.
            await connection.stop()
            onboarding = .addKey(identity)
        }
    }

    private func finishRepairingCancelled() {
        isRepairing = false
        onboarding = nil
        onboardingHistory.removeAll()
        startConnectionIfPossible()
    }

    func removeVehicle() {
        guard let identity else { return }
        page = nil
        Task {
            await connection.reset()
            try? identityStore.forget(identity)
            self.identity = nil
            onboardingHistory.removeAll()
            onboarding = .welcome
        }
    }

    private func onStepChange(_ step: OnboardingStep) {
        switch step {
        case .finding, .chooseCar:
            scanner.start()
        default:
            scanner.stop()
        }
    }
}

#if DEBUG
extension AppModel {
    /// Launch with `-VelaFixtures <driving|parked|connecting|lost>` to look at
    /// the dashboard in the simulator, which has no Bluetooth. DEBUG only.
    static func fromLaunchArguments() -> AppModel {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-VelaFixtures"), index + 1 < args.count else {
            return AppModel()
        }
        let (link, readings): (LinkState, VehicleReadings) = switch args[index + 1] {
        case "parked": (.connected, PreviewFixtures.parked)
        case "connecting": (.connecting, VehicleReadings())
        case "lost": (.lost, PreviewFixtures.driving)
        default: (.connected, PreviewFixtures.driving)
        }
        let page: DashboardPage? = switch args.dropFirst(index + 2).first {
        case "music": .music
        case "climate": .climate
        case "settings": .settings
        default: nil
        }
        let model = preview(link: link, readings: readings, page: page)
        model.usesFixtures = true
        return model
    }

    /// SwiftUI previews only. Never starts Bluetooth: previews have no active
    /// scene, so `startConnectionIfPossible` never runs.
    static func preview(
        link: LinkState,
        readings: VehicleReadings,
        onboarding: OnboardingStep? = nil,
        page: DashboardPage? = nil
    ) -> AppModel {
        let defaults = UserDefaults(suiteName: "vela.preview") ?? .standard
        let model = AppModel(settings: AppSettings(defaults: defaults))
        model.identity = PreviewFixtures.identity
        model.onboarding = onboarding
        model.page = page
        model.connection.loadPreview(link: link, readings: readings)
        return model
    }
}
#endif
