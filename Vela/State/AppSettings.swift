import Foundation
import Observation

enum SpeedUnit: String, CaseIterable, Sendable {
    case mph
    case kmh
}

enum Appearance: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

enum SpeedTint: String, CaseIterable, Sendable {
    case pure, graphite, sand, sage, ice, lilac

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

enum SpeedGround: String, CaseIterable, Sendable {
    /// Black in dark mode, white in light mode.
    case pure
    /// Graphite in dark mode, Paper in light mode.
    case soft

    func displayName(dark: Bool) -> String {
        switch (self, dark) {
        case (.pure, true): "Black"
        case (.pure, false): "White"
        case (.soft, true): "Graphite"
        case (.soft, false): "Paper"
        }
    }
}

enum SpeedNumerals: String, CaseIterable, Sendable {
    case regular
    case bold
}

enum PressureUnit: String, CaseIterable, Sendable {
    case bar
    case psi
}

/// User preferences, persisted in `UserDefaults`.
@MainActor
@Observable
final class AppSettings {
    var units: SpeedUnit { didSet { save(units.rawValue, .units) } }
    var appearance: Appearance { didSet { save(appearance.rawValue, .appearance) } }
    var tint: SpeedTint { didSet { save(tint.rawValue, .tint) } }
    var ground: SpeedGround { didSet { save(ground.rawValue, .ground) } }
    var numerals: SpeedNumerals { didSet { save(numerals.rawValue, .numerals) } }
    var keepScreenOn: Bool { didSet { save(keepScreenOn, .keepScreenOn) } }
    /// Climate page "Sync both sides". An app-side behavior: while on, a
    /// driver change is sent to both zones.
    var syncClimateZones: Bool { didSet { save(syncClimateZones, .syncClimateZones) } }
    var pressureUnit: PressureUnit { didSet { save(pressureUnit.rawValue, .pressureUnit) } }
    var dashboard: DashboardConfig {
        didSet {
            if let data = try? JSONEncoder().encode(dashboard) { save(data, .dashboard) }
        }
    }

    private enum Key: String {
        case units, appearance, tint, ground, numerals, keepScreenOn, syncClimateZones, pressureUnit, dashboard
        var name: String { "vela.settings.\(rawValue)" }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func read<T: RawRepresentable>(_ key: Key, _ fallback: T) -> T where T.RawValue == String {
            guard let raw = defaults.string(forKey: key.name) else { return fallback }
            return T(rawValue: raw) ?? fallback
        }
        units = read(.units, Locale.current.measurementSystem == .metric ? SpeedUnit.kmh : .mph)
        appearance = read(.appearance, Appearance.system)
        tint = read(.tint, SpeedTint.pure)
        ground = read(.ground, SpeedGround.pure)
        numerals = read(.numerals, SpeedNumerals.regular)
        keepScreenOn = defaults.object(forKey: Key.keepScreenOn.name) as? Bool ?? true
        syncClimateZones = defaults.object(forKey: Key.syncClimateZones.name) as? Bool ?? true
        pressureUnit = read(.pressureUnit, Locale.current.measurementSystem == .us ? PressureUnit.psi : .bar)
        dashboard = defaults.data(forKey: Key.dashboard.name)
            .flatMap { try? JSONDecoder().decode(DashboardConfig.self, from: $0) } ?? .default
    }

    private func save(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.name)
    }
}
