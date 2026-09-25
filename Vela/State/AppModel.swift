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
    case music, climate, settings, controls, chargers, vehicle, charging
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
    let network = NetworkMonitor()
    private let identityStore: VehicleIdentityStore

    /// Non-nil while the onboarding / pairing flow is on screen.
    var onboarding: OnboardingStep?
    private var onboardingHistory: [OnboardingStep] = []
    /// True when pairing was started from Settings ("Pair again"): cancel
    /// goes back to the dashboard instead of the start of setup.
    private(set) var isRepairing = false
    private(set) var identity: VehicleIdentity?

    var page: DashboardPage? {
        didSet {
            lastPageInteraction = .now
            connection.detail = switch page {
            case .music: .music
            case .climate: .climate
            case .controls: .controls
            case .vehicle: .vehicle
            case .charging: .charging
            default: .none
            }
            if page == .chargers, connection.superchargers == nil {
                Task { await connection.refreshSuperchargers() }
            }
        }
    }

    private var lastPageInteraction = Date.now
    private var pageIdleTask: Task<Void, Never>?
    private(set) var isSceneActive = false
    private var backgroundStop: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    /// Setpoints the user just chose, shown until the car reports them.
    private var climateDraft: (driverC: Double, passengerC: Double, until: Date)?
    private var climateSend: Task<Void, Never>?
    /// Seat levels just tapped, shown until the car reports them.
    private var seatDraft: [String: (level: Int, until: Date)] = [:]
    /// Volume while the slider is being dragged.
    var volumeDraft: Double?
    /// Controls with a command in flight.
    private(set) var busyControls: Set<String> = []
    /// Charging auto-opens once per session, not again after being closed.
    private var chargingShownForSession = false

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

    var vehicleName: String { identity?.modelName ?? "Tesla" }
    private var readings: VehicleReadings { connection.readings }

    // MARK: - Scene lifecycle

    func sceneDidChange(to phase: ScenePhase) {
        switch phase {
        case .active:
            isSceneActive = true
            backgroundStop?.cancel()
            backgroundStop = nil
            endBackgroundTask()
            startConnectionIfPossible()
            startWatchers()
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

    // MARK: - Dashboard state

    var link: LinkState { connection.link }
    var isLive: Bool { connection.link == .connected }

    /// Parked means gear P and speed 0, as the car reports it.
    var isParked: Bool {
        guard let drive = readings.drive, drive.gear == .park else { return false }
        return (drive.speedMph ?? 0) < 0.5
    }

    var isInGear: Bool {
        guard let gear else { return false }
        return gear != .park
    }

    /// Speed in the chosen unit, from the car's last drive response. `nil`
    /// means the car sent no speed and isn't in Park.
    var displaySpeed: Int? {
        guard let drive = readings.drive else { return nil }
        guard let mph = drive.speedMph else {
            return drive.gear == .park ? 0 : nil
        }
        let value = settings.units == .mph ? mph : mph * 1.609344
        return Int(value.rounded())
    }

    var gear: Gear? { readings.drive?.gear }
    var batteryLevel: Int? { readings.charge?.batteryLevel }
    var unitLabel: String { settings.units == .mph ? "MPH" : "KM/H" }
    var powerKW: Int? { readings.drive?.powerKW }

    /// Settings only when parked or not live.
    var showsSettingsButton: Bool { !isLive || isParked }

    func distanceLabel(miles: Double) -> String {
        switch settings.units {
        case .mph: "\(Int(miles.rounded())) mi"
        case .kmh: "\(Int((miles * 1.609344).rounded())) km"
        }
    }

    var rangeLabel: String? {
        readings.charge?.ratedRangeMiles.map(distanceLabel(miles:))
    }

    var insideTempLabel: String? { climate?.insideC.map { temperatureLabel($0) } }
    var outsideTempLabel: String? { climate?.outsideC.map { temperatureLabel($0) } }

    var headingDegrees: Double? { readings.location?.headingDegrees }

    var headingLabel: String? {
        guard let degrees = headingDegrees else { return nil }
        let names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360 + 22.5) / 45).rounded(.down)) % 8
        return names[index]
    }

    var location: LocationReading? { readings.location }

    /// The route, only while the car navigates.
    var route: RouteReading? {
        guard let route = readings.drive?.route, route.destination != nil || route.minutesToArrival != nil else { return nil }
        return route
    }

    func minutesLabel(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        return total >= 60 ? "\(total / 60) h \(total % 60) min" : "\(total) min"
    }

    // MARK: - Alerts and vehicle status

    var tireWarnings: Set<TireReading.Position> {
        settings.dashboard.alertOn(.tire) ? readings.tires?.warning ?? [] : []
    }

    var openParts: Set<ClosuresReading.Part> {
        settings.dashboard.alertOn(.door) ? readings.closures?.open ?? [] : []
    }

    var closures: ClosuresReading? { readings.closures }
    var tires: TireReading? { readings.tires }

    /// The one alert shown in the driving header, most important first.
    var drivingAlert: (icon: VelaGlyph, label: String)? {
        guard isLive, !isParked else { return nil }
        if !tireWarnings.isEmpty { return (.tire, "Tire pressure") }
        if let part = Self.alertOrder.first(where: openParts.contains) {
            return (.door, "\(Self.name(of: part)) open")
        }
        return nil
    }

    private static let alertOrder: [ClosuresReading.Part] = [
        .frontLeftDoor, .frontRightDoor, .rearLeftDoor, .rearRightDoor, .trunk, .frunk,
        .frontLeftWindow, .frontRightWindow, .rearLeftWindow, .rearRightWindow, .sunroof,
    ]

    static func name(of part: ClosuresReading.Part) -> String {
        switch part {
        case .frontLeftDoor: "Front left door"
        case .frontRightDoor: "Front right door"
        case .rearLeftDoor: "Rear left door"
        case .rearRightDoor: "Rear right door"
        case .frunk: "Front trunk"
        case .trunk: "Trunk"
        case .frontLeftWindow: "Front left window"
        case .frontRightWindow: "Front right window"
        case .rearLeftWindow: "Rear left window"
        case .rearRightWindow: "Rear right window"
        case .sunroof: "Sunroof"
        }
    }

    static func name(of tire: TireReading.Position) -> String {
        switch tire {
        case .frontLeft: "Front left"
        case .frontRight: "Front right"
        case .rearLeft: "Rear left"
        case .rearRight: "Rear right"
        }
    }

    /// Everything that needs attention, for the Vehicle page.
    var issues: [(glyph: VelaGlyph, text: String)] {
        let tireIssues = TireReading.Position.allCases.filter(tireWarnings.contains).map {
            (VelaGlyph.tire, "\(Self.name(of: $0)) tire low")
        }
        let openIssues = Self.alertOrder.filter(openParts.contains).map { part -> (VelaGlyph, String) in
            let glyph: VelaGlyph = switch part {
            case .trunk: .rearTrunk
            case .frunk: .frontTrunk
            case .frontLeftWindow, .frontRightWindow, .rearLeftWindow, .rearRightWindow: .window
            case .sunroof: .sunroof
            default: .door
            }
            return (glyph, "\(Self.name(of: part)) open")
        }
        return tireIssues + openIssues
    }

    var attentionCount: Int { tireWarnings.count + openParts.count }

    var showsUpdateBadge: Bool {
        guard settings.dashboard.alertOn(.update) else { return false }
        return readings.softwareUpdate == .available || readings.softwareUpdate == .scheduled
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

    /// Pages close by themselves after 10 s idle while the car is in gear;
    /// Charging opens by itself once when charging starts while parked; the
    /// secondary poll learns which extra categories the screen needs.
    private func startWatchers() {
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
                self.updateChargingPage()
                self.updateInterest()
            }
        }
    }

    private func updateChargingPage() {
        let charging = readings.charge?.isCharging == true && isParked
        if charging, !chargingShownForSession, page == nil {
            chargingShownForSession = true
            page = .charging
        }
        if !charging {
            chargingShownForSession = false
            if page == .charging, readings.charge?.isCharging != true { page = nil }
        }
    }

    private func updateInterest() {
        let config = settings.dashboard
        let wantsLocation = [DashboardModule.map, .heading].contains { module in
            config.isOn(module, landscape: false) || config.isOn(module, landscape: true)
        }
        let interest = VehicleConnection.Interest(
            location: wantsLocation,
            softwareUpdate: isParked && config.alertOn(.update)
        )
        if connection.interest != interest { connection.interest = interest }
    }

    var isCharging: Bool { readings.charge?.isCharging == true }
    var charge: ChargeReading? { readings.charge }

    // MARK: - Climate

    var climate: ClimateReading? { readings.climate }
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
            let ok = await self.connection.climate(.temperatures(driverC: driverC, passengerC: passengerC))
            // The refresh inside the command now carries the car's value.
            if !ok || self.climateDraft?.driverC == driverC {
                self.climateDraft = nil
            }
        }
    }

    func seatHeatLevel(_ seat: ClimateReading.Seat) -> Int? {
        seatLevel(key: "heat\(seat)", reported: climate?.seatHeat[seat])
    }

    func seatCoolLevel(_ seat: ClimateReading.Seat) -> Int? {
        seatLevel(key: "cool\(seat)", reported: climate?.seatCool[seat])
    }

    private func seatLevel(key: String, reported: Int?) -> Int? {
        guard let reported else { return nil }
        if let draft = seatDraft[key], draft.until > .now { return draft.level }
        return reported
    }

    /// Seat buttons cycle Off → 1 → 2 → 3 → Off, like the car.
    func cycleSeatHeat(_ seat: ClimateReading.Seat) {
        guard let level = seatHeatLevel(seat) else { return }
        let next = (level + 1) % 4
        seatDraft["heat\(seat)"] = (next, .now.addingTimeInterval(6))
        climateAction(.seatHeat(seat, next))
    }

    func cycleSeatCool(_ seat: ClimateReading.Seat) {
        guard let level = seatCoolLevel(seat) else { return }
        let next = (level + 1) % 4
        seatDraft["cool\(seat)"] = (next, .now.addingTimeInterval(6))
        climateAction(.seatCool(seat, next))
    }

    func climateAction(_ action: VehicleConnection.ClimateAction) {
        notePageInteraction()
        Task { await connection.climate(action) }
    }

    // MARK: - Media

    var media: MediaReading? { readings.media }
    var hasMedia: Bool { media?.isActive == true }

    func mediaAction(_ action: VehicleConnection.MediaAction) {
        notePageInteraction()
        Task { await connection.media(action) }
    }

    func commitVolume() {
        guard let volume = volumeDraft else { return }
        Task {
            await connection.media(.setVolume(volume))
            volumeDraft = nil
        }
    }

    // MARK: - Controls

    func control(_ action: VehicleConnection.ControlAction, key: String) {
        notePageInteraction()
        guard !busyControls.contains(key) else { return }
        busyControls.insert(key)
        Task {
            await connection.control(action)
            busyControls.remove(key)
        }
    }

    func isBusy(_ key: String) -> Bool { busyControls.contains(key) }

    // MARK: - Superchargers

    var superchargers: [SuperchargerSite]? { connection.superchargers }
    var isLoadingSuperchargers: Bool { connection.isLoadingSuperchargers }

    func refreshSuperchargers() {
        Task { await connection.refreshSuperchargers() }
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

    /// "Search again" on Choose your car.
    func searchAgain() {
        onboardingHistory.removeAll { step in
            if case .chooseCar = step { true } else if case .finding = step { true } else { false }
        }
        onboarding = .finding
        onStepChange(.finding)
    }

    /// Cancel while pairing returns to choosing a car (or the dashboard when
    /// re-pairing from Settings).
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

    /// "Check the VIN" after pairing failed.
    func recheckVIN() {
        pairing.cancel()
        onboardingHistory.removeAll { step in
            if case .confirmInCar = step { true } else if case .addKey = step { true } else { false }
        }
        onboarding = .enterVIN(expectedLocalName: nil)
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

    #if DEBUG
    fileprivate(set) var usesFixtures = false
    #endif
}

#if DEBUG
extension AppModel {
    /// Launch with `-VelaFixtures <driving|parked|charging|connecting|asleep|lost>`
    /// and optionally a page name to look at screens in the simulator, which
    /// has no Bluetooth. DEBUG only.
    static func fromLaunchArguments() -> AppModel {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-VelaFixtures"), index + 1 < args.count else {
            return AppModel()
        }
        let (link, readings): (LinkState, VehicleReadings) = switch args[index + 1] {
        case "parked": (.connected, PreviewFixtures.parked)
        case "charging": (.connected, PreviewFixtures.charging)
        case "full": (.connected, PreviewFixtures.drivingWithAlerts)
        case "connecting": (.connecting, VehicleReadings())
        case "asleep": (.asleep, VehicleReadings())
        case "btoff": (.bluetoothOff, VehicleReadings())
        case "noperm": (.bluetoothUnauthorized, VehicleReadings())
        case "lost": (.lost, PreviewFixtures.driving)
        default: (.connected, PreviewFixtures.driving)
        }
        let page: DashboardPage? = switch args.dropFirst(index + 2).first {
        case "music": .music
        case "climate": .climate
        case "settings": .settings
        case "controls": .controls
        case "chargers": .chargers
        case "vehicle": .vehicle
        case "charging": .charging
        default: nil
        }
        let model = preview(link: link, readings: readings, page: page)
        if args.contains("-VelaAllModules") {
            model.settings.dashboard = PreviewFixtures.allModules
        }
        model.usesFixtures = true
        return model
    }

    /// SwiftUI previews only. Never starts Bluetooth.
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
        model.connection.loadPreview(link: link, readings: readings, superchargers: PreviewFixtures.superchargers)
        model.usesFixtures = true
        model.page = page
        return model
    }
}
#endif
