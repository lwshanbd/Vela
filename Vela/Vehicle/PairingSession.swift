import Foundation
import Observation
import OSLog
import TeslaBLE

/// First-time pairing, following swift-tesla-ble's documented flow and
/// Tesla's vehicle-command `add-key-request`:
///
/// 1. Load or create this phone's P-256 key for the VIN (Keychain).
/// 2. Connect in `.pairing` mode (BLE only, no session).
/// 3. Send the unsigned VCSEC `addKey` whitelist request.
/// 4. The driver taps their key card and confirms on the touchscreen.
/// 5. Retry a normal signed handshake until the car accepts the new key.
@MainActor
@Observable
final class PairingSession {
    enum Phase: Equatable {
        case idle
        /// Scanning for and connecting to the car.
        case findingCar
        /// addKey sent; waiting for the owner to approve in the car.
        case waitingForApproval
        case paired
        case failed(Failure)
    }

    struct Failure: Equatable, Sendable {
        let title: String
        let detail: String

        static let timedOut = Failure(
            title: String(localized: "Your car didn't confirm"),
            detail: String(localized: "Pairing timed out. Try again and, when the touchscreen asks, tap your key card on the card reader, then tap Confirm.")
        )
    }

    private(set) var phase: Phase = .idle
    private let store: VehicleIdentityStore
    private var task: Task<Void, Never>?
    private let bleLogger = OSLogTeslaBLELogger(subsystem: "com.baodi.vela")
    private let log = Logger(subsystem: "com.baodi.vela", category: "pairing")

    /// How long to wait for the owner to approve on the touchscreen.
    private static let approvalWindow: Duration = .seconds(180)

    init(store: VehicleIdentityStore) {
        self.store = store
    }

    func start(_ identity: VehicleIdentity) {
        cancel()
        phase = .findingCar
        task = Task { [weak self] in
            await self?.run(identity)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    private func run(_ identity: VehicleIdentity) async {
        do {
            let key = try store.loadOrCreateKey(for: identity.vin)
            let publicKey = KeyPairFactory.publicKeyBytes(of: key)

            let pairingClient = TeslaVehicleClient(vin: identity.vin, keyStore: store.keyStore, logger: bleLogger)
            do {
                try await pairingClient.connect(mode: .pairing, timeout: .seconds(30))
                try await pairingClient.send(
                    .security(.addKey(publicKey: publicKey, role: .owner, formFactor: .iosDevice))
                )
            } catch {
                await pairingClient.disconnect()
                throw error
            }
            await pairingClient.disconnect()
            guard !Task.isCancelled else { return }
            phase = .waitingForApproval

            // The key becomes usable once the owner approves. Until then the
            // signed handshake fails; keep trying inside the approval window.
            let clock = ContinuousClock()
            let deadline = clock.now + Self.approvalWindow
            while clock.now < deadline {
                try await Task.sleep(for: .seconds(3))
                let probe = TeslaVehicleClient(vin: identity.vin, keyStore: store.keyStore, logger: bleLogger)
                do {
                    try await probe.connect(mode: .normal, timeout: .seconds(15))
                    await probe.disconnect()
                    store.markPaired(identity)
                    phase = .paired
                    return
                } catch {
                    await probe.disconnect()
                    if Task.isCancelled { return }
                    log.notice("waiting for approval: \(String(describing: error), privacy: .public)")
                }
            }
            phase = .failed(.timedOut)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            log.error("pairing failed: \(String(describing: error), privacy: .public)")
            phase = .failed(Failure(title: String(localized: "Couldn't reach your car"), detail: Self.message(for: error)))
        }
    }

    private static func message(for error: Error) -> String {
        switch error as? TeslaBLEError {
        case .bluetoothUnavailable:
            String(localized: "Bluetooth is off or not allowed for Vela.")
        case .scanTimeout:
            String(localized: "Couldn't find the car. Stay close to it and check the VIN.")
        case .addKeyFailed, .connectionFailed, .serviceNotFound, .characteristicsNotFound:
            String(localized: "The car didn't accept the request. Try again from inside the car.")
        case .keychain:
            String(localized: "Couldn't save the key on this iPhone.")
        default:
            String(localized: "Something went wrong. Try again.")
        }
    }
}
