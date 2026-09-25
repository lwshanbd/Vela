import Foundation

/// Optional dashboard modules. Speed, gear and battery are always shown.
enum DashboardModule: String, Codable, CaseIterable, Sendable {
    case power, range, temps, heading, nav, map, climate, media

    var title: String {
        switch self {
        case .power: String(localized: "Power")
        case .range: String(localized: "Range")
        case .temps: String(localized: "Temperature")
        case .heading: String(localized: "Heading")
        case .nav: String(localized: "Navigation")
        case .map: String(localized: "Map")
        case .climate: String(localized: "Climate")
        case .media: String(localized: "Media")
        }
    }

    var subtitle: String {
        switch self {
        case .power: String(localized: "kW the motor is using")
        case .range: String(localized: "Rated range left")
        case .temps: String(localized: "Inside and outside")
        case .heading: String(localized: "N, NE, E …")
        case .nav: String(localized: "Only while the car navigates")
        case .map: String(localized: "Needs internet")
        case .climate: String(localized: "Set temperature")
        case .media: String(localized: "Hidden when nothing plays")
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
        case .tire: String(localized: "Tire warnings")
        case .door: String(localized: "Doors and windows")
        case .update: String(localized: "Software updates")
        }
    }

    var subtitle: String {
        switch self {
        case .tire: String(localized: "Only when a tire warns")
        case .door: String(localized: "Only when something is open")
        case .update: String(localized: "Parked only")
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
