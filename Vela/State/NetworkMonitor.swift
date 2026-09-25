import Foundation
import Network
import Observation

/// Whether the phone has internet, for the map module: tiles need it, the
/// compass fallback doesn't.
@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "vela.network"))
    }

    deinit {
        monitor.cancel()
    }
}
