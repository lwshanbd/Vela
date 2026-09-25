import Foundation

/// Optional dashboard modules. Speed, gear and battery are always shown.
enum DashboardModule: String, Codable, CaseIterable, Sendable {
    case power, range, temps, heading, nav, map, climate, media

    var title: String {
        switch self {
        case .power: "Power"
        case .range: "Range"
        case .temps: "Temperature"
        case .heading: "Heading"
        case .nav: "Navigation"
        case .map: "Map"
        case .climate: "Climate"
        case .media: "Media"
        }
    }

    var subtitle: String {
        switch self {
        case .power: "kW the motor is using"
        case .range: "Rated range left"
        case .temps: "Inside and outside"
        case .heading: "N, NE, E …"
        case .nav: "Only while the car navigates"
        case .map: "Needs internet"
        case .climate: "Set temperature"
        case .media: "Hidden when nothing plays"
        }
    }

    /// Range, temperature and heading share one chip row.
    var isChip: Bool { self == .range || self == .temps || self == .heading }
}

struct ModuleEntry: Codable, Equatable, Sendable, Identifiable {
    var module: DashboardModule
    var isOn: Bool
    var id: DashboardModule { module }
}

enum DashboardAlert: String, Codable, CaseIterable, Sendable {
    case tire, door, update

    var title: String {
        switch self {
        case .tire: "Tire warnings"
        case .door: "Doors and windows"
        case .update: "Software updates"
        }
    }

    var subtitle: String {
        switch self {
        case .tire: "Only when a tire warns"
        case .door: "Only when something is open"
        case .update: "Parked only"
        }
    }
}

/// Which modules each orientation shows, in layout order. List order is
/// layout order; a module that doesn't fit waits rather than squeezing.
struct DashboardConfig: Codable, Equatable, Sendable {
    var portrait: [ModuleEntry]
    var landscape: [ModuleEntry]
    var alerts: [DashboardAlert: Bool]

    static let `default` = DashboardConfig(
        portrait: [.power, .range, .temps, .heading, .nav, .map, .climate, .media].map {
            ModuleEntry(module: $0, isOn: [.nav, .climate, .media].contains($0))
        },
        landscape: [.power, .range, .temps, .heading, .nav, .map, .media, .climate].map {
            ModuleEntry(module: $0, isOn: [.nav, .climate, .media].contains($0))
        },
        alerts: [.tire: true, .door: true, .update: true]
    )

    func entries(landscape: Bool) -> [ModuleEntry] {
        landscape ? self.landscape : portrait
    }

    func isOn(_ module: DashboardModule, landscape: Bool) -> Bool {
        entries(landscape: landscape).first { $0.module == module }?.isOn ?? false
    }

    func alertOn(_ alert: DashboardAlert) -> Bool {
        alerts[alert] ?? true
    }

    var enabledCount: Int {
        Set(portrait.filter(\.isOn).map(\.module)).union(landscape.filter(\.isOn).map(\.module)).count
    }
}
