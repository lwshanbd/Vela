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
/// `link` and `readings`.
@MainActor
@Observable
final class VehicleConnection {
    enum Detail: Sendable {
        case none
        case music
        case climate
    }

    enum MediaAction: Sendable {
        case togglePlayback, next, previous, volumeUp, volumeDown
    }

    private(set) var link: LinkState = .idle
    private(set) var readings = VehicleReadings()
    /// The page on screen. Music and Climate pages refresh their data faster.
    var detail: Detail = .none

    private(set) var identity: VehicleIdentity?
    private let keyStore: KeychainTeslaKeyStore
    private var client: TeslaVehicleClient?
    private var supervisor: Task<Void, Never>?
    private let bleLogger = OSLogTeslaBLELogger(subsystem: "com.beadinventory.vela")
    private let log = Logger(subsystem: "com.beadinventory.vela", category: "connection")

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

    /// Starts (or keeps) the session for `identity`. Idempotent: calling it
    /// again for the same car while running does nothing.
    func start(_ identity: VehicleIdentity) {
        if self.identity != identity {
            readings = VehicleReadings()
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
    }

    private func supervise(_ identity: VehicleIdentity) async {
        var hasConnected = false
        var attempt = 0
        while !Task.isCancelled {
            if !(link == .bluetoothOff || link == .bluetoothUnauthorized) {
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
                if case .bluetoothUnavailable = error as? TeslaBLEError {
                    link = CBManager.authorization == .denied || CBManager.authorization == .restricted
                        ? .bluetoothUnauthorized : .bluetoothOff
                } else if link == .bluetoothOff || link == .bluetoothUnauthorized {
                    link = hasConnected ? .lost : .connecting
                }
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
                readings.drive = DriveReading(speedMph: drive.speedMph, gear: drive.shiftState.map(Gear.init))
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

    /// Battery, climate and media. These change slowly, so they share one
    /// request every few seconds instead of competing with drive polls.
    private func pollSecondary(_ client: TeslaVehicleClient) async {
        while !Task.isCancelled {
            await refreshSecondary(client)
            let interval: Duration = detail == .none ? .seconds(5) : .seconds(2)
            try? await Task.sleep(for: interval)
        }
    }

    private func refreshSecondary(_ client: TeslaVehicleClient) async {
        var categories: Set<StateCategory> = [.charge, .climate, .media]
        if detail == .music { categories.insert(.mediaDetail) }
        do {
            let snapshot = try await client.fetch(.categories(categories), timeout: .seconds(5))
            apply(snapshot)
        } catch {
            log.notice("state poll failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func apply(_ snapshot: TeslaVehicleSnapshot) {
        if let level = snapshot.charge?.batteryLevel {
            readings.batteryLevel = level
        }
        if let climate = snapshot.climate,
           let driver = climate.driverTempSettingCelsius,
           let passenger = climate.passengerTempSettingCelsius
        {
            readings.climate = ClimateReading(
                isOn: climate.isClimateOn ?? false,
                driverSetpointC: driver,
                passengerSetpointC: passenger,
                fanLevel: climate.fanStatus
            )
        }
        if let media = snapshot.media {
            var reading = MediaReading(
                isPlaying: media.playbackStatus.map { $0 == .playing },
                title: media.nowPlayingTitle,
                artist: media.nowPlayingArtist,
                volume: media.audioVolume,
                volumeMax: media.audioVolumeMax
            )
            // Detail is only requested while Now Playing is open; keep the
            // last values otherwise so the progress bar doesn't blink.
            let detail = snapshot.mediaDetail
            let previous = readings.media
            let sameTrack = previous?.title == reading.title
            reading.elapsedSeconds = detail?.nowPlayingElapsedSeconds ?? (sameTrack ? previous?.elapsedSeconds : nil)
            reading.durationSeconds = detail?.nowPlayingDurationSeconds ?? (sameTrack ? previous?.durationSeconds : nil)
            readings.media = reading
        }
    }

    // MARK: - Commands

    /// Sends a command on the live session and refreshes climate/media right
    /// after, so the UI reflects what the car actually applied.
    @discardableResult
    private func send(_ command: Command) async -> Bool {
        guard link == .connected, let client else { return false }
        do {
            try await client.send(command, timeout: .seconds(5))
            await refreshSecondary(client)
            return true
        } catch {
            log.notice("command failed: \(String(describing: error), privacy: .public)")
            await refreshSecondary(client)
            return false
        }
    }

    @discardableResult
    func setClimate(on: Bool) async -> Bool {
        await send(.climate(on ? .on : .off))
    }

    @discardableResult
    func setTemperatures(driverC: Double, passengerC: Double) async -> Bool {
        await send(.climate(.setTemperature(driver: Float(driverC), passenger: Float(passengerC))))
    }

    @discardableResult
    func media(_ action: MediaAction) async -> Bool {
        let command: Command.Media = switch action {
        case .togglePlayback: .togglePlayback
        case .next: .nextTrack
        case .previous: .previousTrack
        case .volumeUp: .volumeUp
        case .volumeDown: .volumeDown
        }
        return await send(.media(command))
    }
}

private extension Gear {
    init(_ shift: DriveState.ShiftState) {
        switch shift {
        case .park: self = .park
        case .reverse: self = .reverse
        case .neutral: self = .neutral
        case .drive: self = .drive
        }
    }
}

#if DEBUG
extension VehicleConnection {
    /// SwiftUI previews only. Production readings come from `apply(_:)`.
    func loadPreview(link: LinkState, readings: VehicleReadings) {
        self.link = link
        self.readings = readings
    }
}
#endif
