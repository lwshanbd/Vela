import CoreBluetooth
import Foundation
import Observation
import OSLog
import TeslaBLE

/// Owns the BLE session with the paired Tesla for as long as the app is in the
/// foreground. Lives on `AppModel`, never on a view, so rotation and view
/// rebuilds don't touch the session.
///
/// Lifecycle: `start` runs a supervisor loop that connects, polls, and on any
/// drop reconnects with backoff until `stop` is called. The UI only reads
/// `link`, `readings` and `superchargers`.
@MainActor
@Observable
final class VehicleConnection {
    enum Detail: Sendable {
        case none, music, climate, controls, vehicle, charging
    }

    /// What the secondary poll needs besides the always-on categories.
    struct Interest: Equatable, Sendable {
        var location = false
        var softwareUpdate = false
    }

    enum MediaAction: Sendable {
        case togglePlayback, next, previous, nextFavorite, previousFavorite, volumeUp, volumeDown
        case setVolume(Double)
    }

    enum ControlAction: Sendable {
        case lock, unlock, openFrunk, openTrunk, closeTrunk, ventWindows, closeWindows
        case sentry(Bool), ventSunroof, closeSunroof, openChargePort, closeChargePort
        case honk, flashLights, homelink
    }

    enum ClimateAction: Sendable {
        case power(Bool)
        case temperatures(driverC: Double, passengerC: Double)
        case seatHeat(ClimateReading.Seat, Int)
        case seatCool(ClimateReading.Seat, Int)
        case steeringWheelHeat(Bool)
        case autoSeatClimate(Bool)
        case maxDefrost(Bool)
        case keeper(ClimateReading.KeeperMode)
        case overheatProtection(ClimateReading.OverheatProtection)
        case overheatTemp(ClimateReading.OverheatTemp)
        case bioweapon(Bool)
    }

    private(set) var link: LinkState = .idle
    private(set) var readings = VehicleReadings()
    private(set) var superchargers: [SuperchargerSite]?
    private(set) var isLoadingSuperchargers = false
    /// The page on screen. Detail pages refresh their data faster.
    var detail: Detail = .none
    var interest = Interest()

    private(set) var identity: VehicleIdentity?
    private let keyStore: KeychainTeslaKeyStore
    private var client: TeslaVehicleClient?
    private var supervisor: Task<Void, Never>?
    private let bleLogger = OSLogTeslaBLELogger(subsystem: "com.baodi.vela")
    private let log = Logger(subsystem: "com.baodi.vela", category: "connection")

    /// Speed display refresh is capped at 4 Hz (design: "digits never
    /// flicker"). The car usually takes longer than this to answer, so in
    /// practice drive state is requested back to back.
    private static let driveInterval: Duration = .milliseconds(250)
    /// In Park the speed can't change; poll gently.
    private static let parkedDriveInterval: Duration = .seconds(1)
    /// Consecutive drive-poll failures before the session is treated as lost.
    private static let driveFailureLimit = 4

    init(keyStore: KeychainTeslaKeyStore) {
        self.keyStore = keyStore
    }

    // MARK: - Lifecycle

    /// Starts (or keeps) the session for `identity`. Idempotent.
    func start(_ identity: VehicleIdentity) {
        if self.identity != identity {
            readings = VehicleReadings()
            superchargers = nil
        }
        self.identity = identity
        guard supervisor == nil else { return }
        supervisor = Task { [weak self] in
            await self?.supervise(identity)
        }
    }

    /// Ends the session and stops reconnecting. Readings are kept so the UI
    /// shows the last known state on return.
    func stop() async {
        supervisor?.cancel()
        supervisor = nil
        if let client {
            await client.disconnect()
        }
        client = nil
        link = .idle
    }

    /// Stops and forgets the vehicle's readings, for Remove vehicle.
    func reset() async {
        await stop()
        identity = nil
        readings = VehicleReadings()
        superchargers = nil
    }

    private func supervise(_ identity: VehicleIdentity) async {
        var hasConnected = false
        var attempt = 0
        while !Task.isCancelled {
            if ![.bluetoothOff, .bluetoothUnauthorized, .asleep].contains(link) {
                link = hasConnected ? .lost : .connecting
            }
            let client = TeslaVehicleClient(vin: identity.vin, keyStore: keyStore, logger: bleLogger)
            self.client = client
            do {
                try await client.connect(mode: .normal, timeout: .seconds(20))
                guard !Task.isCancelled else { break }
                link = .connected
                hasConnected = true
                attempt = 0
                await runSession(client)
                log.notice("session ended")
            } catch {
                guard !Task.isCancelled else { break }
                log.notice("connect failed: \(String(describing: error), privacy: .public)")
                await client.disconnect()
                link = await classify(error, identity: identity, hasConnected: hasConnected)
            }
            await client.disconnect()
            if self.client === client { self.client = nil }
            guard !Task.isCancelled else { break }

            // Backoff: 1, 2, 4, 8, 10, 10 … seconds. The scan inside connect
            // already waits up to 20 s for a car that isn't in range.
            attempt += 1
            let delay = min(10, 1 << min(attempt - 1, 4))
            try? await Task.sleep(for: .seconds(delay))
        }
    }

    /// Maps a failed connect to what the user should see. A handshake that
    /// fails after the car was found is usually a sleeping car: its body
    /// controller still answers an unsigned status request, which says so.
    private func classify(_ error: Error, identity: VehicleIdentity, hasConnected: Bool) async -> LinkState {
        let fallback: LinkState = hasConnected ? .lost : .connecting
        switch error as? TeslaBLEError {
        case .bluetoothUnavailable:
            return CBManager.authorization == .denied || CBManager.authorization == .restricted
                ? .bluetoothUnauthorized : .bluetoothOff
        case .handshakeFailed:
            return await isAsleep(identity) ? .asleep : fallback
        default:
            return fallback
        }
    }

    private func isAsleep(_ identity: VehicleIdentity) async -> Bool {
        let probe = TeslaVehicleClient(vin: identity.vin, keyStore: keyStore, logger: bleLogger)
        defer { Task { await probe.disconnect() } }
        do {
            try await probe.connect(mode: .pairing, timeout: .seconds(10))
            guard case let .bodyControllerState(status) = try await probe.query(.bodyControllerState, timeout: .seconds(3))
            else { return false }
            return status.vehicleSleepStatus == .vehicleSleepStatusAsleep
        } catch {
            log.notice("sleep probe failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// Polls until the link drops or the car stops answering.
    private func runSession(_ client: TeslaVehicleClient) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in await self?.pollDrive(client) }
            group.addTask { [weak self] in await self?.pollSecondary(client) }
            group.addTask {
                // The stream replays earlier transitions; only a drop matters.
                for await state in client.stateStream where state == .disconnected {
                    return
                }
            }
            // The first task to finish means the session is over.
            await group.next()
            group.cancelAll()
        }
    }

    private func pollDrive(_ client: TeslaVehicleClient) async {
        var failures = 0
        let clock = ContinuousClock()
        while !Task.isCancelled {
            let started = clock.now
            do {
                let drive = try await client.fetchDrive(timeout: .seconds(3))
                readings.drive = Self.map(drive)
                failures = 0
            } catch {
                if Task.isCancelled { return }
                failures += 1
                log.notice("drive poll failed (\(failures)): \(String(describing: error), privacy: .public)")
                if failures >= Self.driveFailureLimit { return }
            }
            let interval = readings.drive?.gear == .park ? Self.parkedDriveInterval : Self.driveInterval
            try? await Task.sleep(until: started + interval, clock: clock)
        }
    }

    /// Battery, climate, media, closures and tires. These change slowly, so
    /// they share one request every few seconds instead of competing with
    /// drive polls.
    private func pollSecondary(_ client: TeslaVehicleClient) async {
        while !Task.isCancelled {
            await refreshSecondary(client)
            let interval: Duration = detail == .none ? .seconds(5) : .seconds(2)
            try? await Task.sleep(for: interval)
        }
    }

    private func refreshSecondary(_ client: TeslaVehicleClient) async {
        var categories: Set<StateCategory> = [.charge, .climate, .media, .closures, .tirePressure]
        if detail == .music { categories.insert(.mediaDetail) }
        if interest.location || detail == .controls { categories.insert(.location) }
        if interest.softwareUpdate { categories.insert(.softwareUpdate) }
        do {
            let snapshot = try await client.fetch(.categories(categories), timeout: .seconds(5))
            apply(snapshot)
        } catch {
            log.notice("state poll failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Mapping

    private static func map(_ drive: DriveState) -> DriveReading {
        let route: RouteReading? = drive.activeRouteDestination.map {
            RouteReading(
                destination: $0.isEmpty ? nil : $0,
                minutesToArrival: drive.activeRouteMinutesToArrival,
                milesToArrival: drive.activeRouteMilesToArrival,
                trafficDelayMinutes: drive.activeRouteTrafficMinutesDelay
            )
        }
        let gear: Gear? = switch drive.shiftState {
        case .park?: .park
        case .reverse?: .reverse
        case .neutral?: .neutral
        case .drive?: .drive
        case nil: nil
        }
        return DriveReading(speedMph: drive.speedMph, gear: gear, powerKW: drive.powerKW, route: route)
    }

    private func apply(_ snapshot: TeslaVehicleSnapshot) {
        if let charge = snapshot.charge {
            readings.charge = Self.map(charge)
        }
        if let climate = snapshot.climate {
            readings.climate = Self.map(climate) ?? readings.climate
        }
        if let media = snapshot.media {
            readings.media = Self.map(media, detail: snapshot.mediaDetail, previous: readings.media)
        }
        if let closures = snapshot.closures {
            readings.closures = Self.map(closures)
        }
        if let tires = snapshot.tirePressure {
            readings.tires = Self.map(tires)
        }
        if let location = snapshot.location {
            readings.location = Self.map(location)
        }
        if let update = snapshot.softwareUpdate {
            readings.softwareUpdate = Self.map(update)
        }
    }

    private static func map(_ charge: ChargeState) -> ChargeReading {
        let status: ChargeReading.Status? = switch charge.chargingStatus {
        case .disconnected?: .disconnected
        case .charging?: .charging
        case .complete?: .complete
        case .stopped?: .stopped
        case .starting?: .starting
        case nil: nil
        }
        return ChargeReading(
            batteryLevel: charge.batteryLevel,
            ratedRangeMiles: charge.batteryRangeMiles,
            status: status,
            limitPercent: charge.chargeLimitPercent,
            minutesToLimit: charge.minutesToChargeLimit,
            minutesToFull: charge.minutesToFullCharge,
            powerKW: charge.chargerPower,
            voltage: charge.chargerVoltage,
            currentAmps: charge.chargerCurrent,
            energyAddedKWh: charge.chargeEnergyAddedKWh,
            isFastCharger: charge.fastChargerPresent,
            portOpen: charge.chargePortOpen
        )
    }

    private static func map(_ climate: ClimateState) -> ClimateReading? {
        guard let driver = climate.driverTempSettingCelsius,
              let passenger = climate.passengerTempSettingCelsius
        else { return nil }
        var reading = ClimateReading(
            isOn: climate.isClimateOn ?? false,
            driverSetpointC: driver,
            passengerSetpointC: passenger,
            insideC: climate.insideTempCelsius,
            outsideC: climate.outsideTempCelsius,
            fanLevel: climate.fanStatus
        )
        let heaters: [(ClimateReading.Seat, ClimateState.SeatHeaterLevel?)] = [
            (.frontLeft, climate.seatHeaterFrontLeft), (.frontRight, climate.seatHeaterFrontRight),
            (.rearLeft, climate.seatHeaterRearLeft), (.rearCenter, climate.seatHeaterRearCenter),
            (.rearRight, climate.seatHeaterRearRight),
        ]
        for (seat, level) in heaters {
            if let level { reading.seatHeat[seat] = level.rawValue }
        }
        if let level = climate.seatFanFrontLeft { reading.seatCool[.frontLeft] = level }
        if let level = climate.seatFanFrontRight { reading.seatCool[.frontRight] = level }
        reading.steeringWheelHeat = climate.steeringWheelHeater
        reading.autoSeatClimate = climate.autoSeatClimateLeft
        reading.frontDefroster = climate.isFrontDefrosterOn
        reading.rearDefroster = climate.isRearDefrosterOn
        reading.maxDefrost = climate.defrostOn
        reading.keeperMode = switch climate.climateKeeperMode {
        case .off?: .off
        case .on?: .on
        case .dog?: .dog
        case .camp?: .camp
        case .unknown?, nil: nil
        }
        reading.overheatProtection = switch climate.cabinOverheatProtection {
        case .off?: .off
        case .on?: .on
        case .fanOnly?: .fanOnly
        case .unknown?, nil: nil
        }
        reading.overheatTemp = switch climate.cabinOverheatProtectionActivationTemp {
        case .low?: .low
        case .medium?: .medium
        case .high?: .high
        case nil: nil
        }
        reading.bioweaponMode = climate.bioweaponMode
        reading.batteryHeater = climate.isBatteryHeaterOn
        reading.wiperHeater = climate.wiperBladeHeater
        reading.mirrorHeaters = climate.sideMirrorHeaters
        return reading
    }

    private static func map(_ media: MediaState, detail: MediaDetailState?, previous: MediaReading?) -> MediaReading {
        let kind: MediaReading.SourceKind? = switch media.nowPlayingSource {
        case .bluetooth?: .bluetooth
        case .am?, .fm?, .xm?, .siriusXm?, .dab?, .tuneIn?, .onlineRadio?: .radio
        case .spotify?, .tidal?, .slacker?, .stingray?, .qqMusic?, .netEaseMusic?, .ximalaya?: .streaming
        case nil: nil
        default: .other
        }
        var reading = MediaReading(
            isPlaying: media.playbackStatus.flatMap { status in
                switch status {
                case .playing: true
                case .paused: false
                case .stopped: nil
                }
            },
            title: media.nowPlayingTitle,
            artist: media.nowPlayingArtist,
            sourceKind: kind,
            volume: media.audioVolume,
            volumeMax: media.audioVolumeMax
        )
        // Detail is only requested while Now Playing is open; keep the last
        // values for the same track so the page doesn't blink.
        let sameTrack = previous?.title == reading.title
        reading.album = detail?.nowPlayingAlbum ?? (sameTrack ? previous?.album : nil)
        reading.station = detail?.nowPlayingStation ?? (sameTrack ? previous?.station : nil)
        reading.sourceName = detail?.a2dpSourceName ?? detail?.nowPlayingSource ?? previous?.sourceName
        reading.elapsedSeconds = detail?.nowPlayingElapsedSeconds ?? (sameTrack ? previous?.elapsedSeconds : nil)
        reading.durationSeconds = detail?.nowPlayingDurationSeconds ?? (sameTrack ? previous?.durationSeconds : nil)
        return reading
    }

    private static func map(_ closures: ClosuresState) -> ClosuresReading {
        var reading = ClosuresReading(locked: closures.locked)
        let parts: [(ClosuresReading.Part, Bool?)] = [
            (.frontLeftDoor, closures.frontDriverDoor), (.frontRightDoor, closures.frontPassengerDoor),
            (.rearLeftDoor, closures.rearDriverDoor), (.rearRightDoor, closures.rearPassengerDoor),
            (.frunk, closures.frontTrunk), (.trunk, closures.rearTrunk),
            (.frontLeftWindow, closures.windowDriverFront), (.frontRightWindow, closures.windowPassengerFront),
            (.rearLeftWindow, closures.windowDriverRear), (.rearRightWindow, closures.windowPassengerRear),
        ]
        for (part, isOpen) in parts where isOpen == true {
            reading.open.insert(part)
        }
        if let sunroof = closures.sunroofState {
            reading.hasSunroof = true
            if sunroof == .open || sunroof == .vent { reading.open.insert(.sunroof) }
        }
        reading.sentry = switch closures.sentryMode {
        case .off?: .off
        case .idle?: .idle
        case .armed?: .armed
        case .aware?: .aware
        case .panic?: .panic
        case .quiet?: .quiet
        case nil: closures.sentryModeActive.map { $0 ? .armed : .off }
        }
        return reading
    }

    private static func map(_ tires: TirePressureState) -> TireReading {
        var reading = TireReading(
            recommendedFrontBar: tires.recommendedColdFrontBar,
            recommendedRearBar: tires.recommendedColdRearBar
        )
        let all: [(TireReading.Position, TirePressureState.Tire?)] = [
            (.frontLeft, tires.frontLeft), (.frontRight, tires.frontRight),
            (.rearLeft, tires.rearLeft), (.rearRight, tires.rearRight),
        ]
        for (position, tire) in all {
            if let bar = tire?.pressureBar { reading.pressureBar[position] = bar }
            if tire?.hasWarning == true { reading.warning.insert(position) }
        }
        return reading
    }

    private static func map(_ location: LocationState) -> LocationReading? {
        guard let coordinate = location.estimatedCoordinate ?? location.coordinate else { return nil }
        return LocationReading(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            headingDegrees: location.estimatedHeadingDegrees ?? location.headingDegrees.map(Double.init),
            placeName: location.locationName.flatMap { $0.isEmpty ? nil : $0 },
            homelinkNearby: location.homelinkNearby
        )
    }

    private static func map(_ update: SoftwareUpdateState) -> SoftwareUpdateReading? {
        switch update.status {
        case .none?: SoftwareUpdateReading.none
        case .downloading?, .downloadingWifiWait?: .downloading
        case .available?: .available
        case .scheduled?: .scheduled
        case .installing?: .installing
        case nil: nil
        }
    }

    // MARK: - Commands

    /// Sends a command on the live session and refreshes state right after,
    /// so the UI reflects what the car actually applied.
    @discardableResult
    private func send(_ command: Command) async -> Bool {
        guard link == .connected, let client else { return false }
        do {
            try await client.send(command, timeout: .seconds(8))
            await refreshSecondary(client)
            return true
        } catch {
            log.notice("command failed: \(String(describing: error), privacy: .public)")
            await refreshSecondary(client)
            return false
        }
    }

    @discardableResult
    func climate(_ action: ClimateAction) async -> Bool {
        let command: Command.Climate
        switch action {
        case let .power(on):
            command = on ? .on : .off
        case let .temperatures(driver, passenger):
            command = .setTemperature(driver: Float(driver), passenger: Float(passenger))
        case let .seatHeat(seat, level):
            let heat: Command.Climate.SeatHeaterLevel = [.off, .low, .medium, .high][min(3, max(0, level))]
            let position: Command.Climate.SeatPosition = switch seat {
            case .frontLeft: .frontLeft
            case .frontRight: .frontRight
            case .rearLeft: .rearLeft
            case .rearCenter: .rearCenter
            case .rearRight: .rearRight
            }
            command = .setSeatHeater(level: heat, seat: position)
        case let .seatCool(seat, level):
            let cool: Command.Climate.SeatCoolerLevel = [.off, .low, .medium, .high][min(3, max(0, level))]
            command = .setSeatCooler(level: cool, seat: seat == .frontRight ? .frontRight : .frontLeft)
        case let .steeringWheelHeat(on):
            command = .setSteeringWheelHeater(on)
        case let .autoSeatClimate(on):
            command = .autoSeatAndClimate(enabled: on, positions: [.frontLeft, .frontRight])
        case let .maxDefrost(on):
            command = .setPreconditioningMax(enabled: on, manualOverride: false)
        case let .keeper(mode):
            let keeper: Command.Climate.ClimateKeeperMode = switch mode {
            case .off: .off
            case .on: .on
            case .dog: .dog
            case .camp: .camp
            }
            command = .setKeeperMode(keeper)
        case let .overheatProtection(mode):
            command = .setCabinOverheatProtection(enabled: mode != .off, fanOnly: mode == .fanOnly)
        case let .overheatTemp(level):
            let temp: Command.Climate.CabinOverheatTemperatureLevel = switch level {
            case .low: .low
            case .medium: .medium
            case .high: .high
            }
            command = .setCabinOverheatProtectionTemperature(level: temp)
        case let .bioweapon(on):
            command = .setBioweaponDefenseMode(enabled: on, manualOverride: false)
        }
        return await send(.climate(command))
    }

    @discardableResult
    func media(_ action: MediaAction) async -> Bool {
        let command: Command.Media = switch action {
        case .togglePlayback: .togglePlayback
        case .next: .nextTrack
        case .previous: .previousTrack
        case .nextFavorite: .nextFavorite
        case .previousFavorite: .previousFavorite
        case .volumeUp: .volumeUp
        case .volumeDown: .volumeDown
        case let .setVolume(volume): .setVolume(Float(volume))
        }
        return await send(.media(command))
    }

    @discardableResult
    func control(_ action: ControlAction) async -> Bool {
        let command: Command
        switch action {
        case .lock: command = .security(.lock)
        case .unlock: command = .security(.unlock)
        case .openFrunk: command = .security(.openFrunk)
        case .openTrunk: command = .security(.openTrunk)
        case .closeTrunk: command = .security(.closeTrunk)
        case .ventWindows: command = .actions(.ventWindows)
        case .closeWindows: command = .actions(.closeWindows)
        case let .sentry(on): command = .security(.setSentryMode(on))
        case .ventSunroof: command = .actions(.changeSunroof(level: 100))
        case .closeSunroof: command = .actions(.changeSunroof(level: 0))
        case .openChargePort: command = .charge(.openPort)
        case .closeChargePort: command = .charge(.closePort)
        case .honk: command = .actions(.honk)
        case .flashLights: command = .actions(.flashLights)
        case .homelink:
            // HomeLink needs the car's position; without it there is nothing to send.
            guard let location = readings.location else { return false }
            command = .actions(.triggerHomelink(latitude: Float(location.latitude), longitude: Float(location.longitude)))
        }
        return await send(command)
    }

    /// Asks the car for nearby Superchargers as its navigation sees them.
    func refreshSuperchargers() async {
        guard link == .connected, let client, !isLoadingSuperchargers else { return }
        isLoadingSuperchargers = true
        defer { isLoadingSuperchargers = false }
        do {
            let result = try await client.query(.nearbyCharging(includeMetadata: true), timeout: .seconds(10))
            guard case let .nearbyCharging(sites) = result else { return }
            superchargers = sites.superchargers
                .map { site in
                    SuperchargerSite(
                        id: site.id,
                        name: site.name,
                        distanceMiles: Double(site.distanceMiles),
                        availableStalls: Int(site.availableStalls),
                        totalStalls: Int(site.totalStalls),
                        isClosed: site.siteClosed,
                        withinRange: site.withinRange
                    )
                }
                .sorted { $0.distanceMiles < $1.distanceMiles }
        } catch {
            log.notice("supercharger query failed: \(String(describing: error), privacy: .public)")
        }
    }
}

#if DEBUG
extension VehicleConnection {
    /// SwiftUI previews only. Production readings come from `apply(_:)`.
    func loadPreview(link: LinkState, readings: VehicleReadings, superchargers: [SuperchargerSite]? = nil) {
        self.link = link
        self.readings = readings
        self.superchargers = superchargers
    }
}
#endif
