import CoreBluetooth
import Foundation
import Observation

/// Lists Tesla vehicles advertising nearby, for the "Choose your car" step.
///
/// A Tesla's BLE local name is "S" + 16 hex digits + "C" (a hash of its VIN,
/// see `VehicleIdentity.bleLocalName`). The VIN itself can't be recovered from
/// the advertisement, so this scanner only answers "which cars are near, and
/// how close". The user then enters the VIN, and Vela checks it hashes to the
/// advertisement they picked. TeslaBLE's own scanner only looks for one known
/// VIN, so it can't do this discovery step.
@MainActor
@Observable
final class NearbyTeslaScanner: NSObject {
    struct Advertisement: Identifiable, Equatable {
        let localName: String
        var rssi: Int
        var lastSeen: Date
        var id: String { localName }
    }

    enum Status: Equatable {
        case idle
        case waitingForBluetooth
        case unauthorized
        case poweredOff
        case scanning
    }

    private(set) var status: Status = .idle
    /// Sorted strongest signal first.
    private(set) var vehicles: [Advertisement] = []

    private var central: CBCentralManager?
    private var wantsScan = false
    private var pruneTask: Task<Void, Never>?

    func start() {
        wantsScan = true
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        }
        updateForState()
        pruneTask?.cancel()
        pruneTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                self?.pruneStale()
            }
        }
    }

    func stop() {
        wantsScan = false
        pruneTask?.cancel()
        pruneTask = nil
        central?.stopScan()
        // Release the manager so TeslaBLE's own CBCentralManager has the radio.
        central?.delegate = nil
        central = nil
        status = .idle
    }

    private func updateForState() {
        guard let central, wantsScan else { return }
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            status = .scanning
        case .unauthorized:
            status = .unauthorized
        case .poweredOff:
            status = .poweredOff
        default:
            status = .waitingForBluetooth
        }
    }

    private func record(localName: String, rssi: Int) {
        // 127 means "RSSI not available".
        guard rssi < 0 else { return }
        let now = Date()
        if let index = vehicles.firstIndex(where: { $0.localName == localName }) {
            // Light smoothing so the list doesn't reshuffle on every packet.
            vehicles[index].rssi = (vehicles[index].rssi * 2 + rssi) / 3
            vehicles[index].lastSeen = now
        } else {
            vehicles.append(Advertisement(localName: localName, rssi: rssi, lastSeen: now))
        }
        vehicles.sort { $0.rssi > $1.rssi }
    }

    private func pruneStale() {
        let cutoff = Date().addingTimeInterval(-10)
        vehicles.removeAll { $0.lastSeen < cutoff }
    }

    nonisolated static func isTeslaLocalName(_ name: String) -> Bool {
        let chars = Array(name)
        guard chars.count == 18, chars.first == "S", chars.last == "C" else { return false }
        return chars[1 ..< 17].allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

extension NearbyTeslaScanner: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_: CBCentralManager) {
        MainActor.assumeIsolated { updateForState() }
    }

    nonisolated func centralManager(
        _: CBCentralManager,
        didDiscover _: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
              Self.isTeslaLocalName(name)
        else { return }
        let rssi = RSSI.intValue
        MainActor.assumeIsolated { record(localName: name, rssi: rssi) }
    }
}
