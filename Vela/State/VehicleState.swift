import Foundation

/// UI-facing connection state. Independent of TeslaBLE's enum so views never
/// see protocol types.
enum LinkState: Equatable, Sendable {
    /// No paired vehicle, or the app is in the background.
    case idle
    /// Scanning, BLE connect, handshake.
    case connecting
    /// The car answered over BLE but its computer is asleep, so the signed
    /// session can't start. Vela keeps retrying; opening a door wakes it.
    case asleep
    /// Session up and data flowing.
    case connected
    /// Was connected, link dropped; reconnecting automatically.
    case lost
    /// Bluetooth is off or not allowed. Reconnects when it comes back.
    case bluetoothOff
    case bluetoothUnauthorized
}

enum Gear: String, Sendable {
    case park = "P"
    case reverse = "R"
    case neutral = "N"
    case drive = "D"
}

struct RouteReading: Equatable, Sendable {
    var destination: String?
    var minutesToArrival: Double?
    var milesToArrival: Double?
    var trafficDelayMinutes: Double?
}

struct DriveReading: Equatable, Sendable {
    /// As reported by the car. `nil` when the car didn't include a speed.
    var speedMph: Double?
    var gear: Gear?
    /// Positive draws energy, negative is regeneration.
    var powerKW: Int?
    /// Present only while the car is navigating.
    var route: RouteReading?
}

struct ChargeReading: Equatable, Sendable {
    enum Status: Sendable { case disconnected, charging, complete, stopped, starting }

    var batteryLevel: Int?
    var ratedRangeMiles: Double?
    var status: Status?
    var limitPercent: Int?
    var minutesToLimit: Int?
    var minutesToFull: Int?
    var powerKW: Int?
    var voltage: Int?
    var currentAmps: Int?
    var energyAddedKWh: Double?
    var isFastCharger: Bool?
    var portOpen: Bool?

    var isCharging: Bool { status == .charging || status == .starting }
}

struct ClimateReading: Equatable, Sendable {
    enum KeeperMode: Sendable { case off, on, dog, camp }
    enum OverheatProtection: Sendable { case off, on, fanOnly }
    enum OverheatTemp: Sendable { case low, medium, high }
    enum Seat: Hashable, Sendable { case frontLeft, frontRight, rearLeft, rearCenter, rearRight }

    var isOn: Bool
    var driverSetpointC: Double
    var passengerSetpointC: Double
    var insideC: Double?
    var outsideC: Double?
    /// Fan level as reported by the car. Read-only over BLE.
    var fanLevel: Int?
    /// Seat heater levels 0–3. A seat is absent when the car has no heater there.
    var seatHeat: [Seat: Int] = [:]
    /// Ventilated seat levels 0–3, front seats only.
    var seatCool: [Seat: Int] = [:]
    var steeringWheelHeat: Bool?
    var autoSeatClimate: Bool?
    var frontDefroster: Bool?
    var rearDefroster: Bool?
    var maxDefrost: Bool?
    var keeperMode: KeeperMode?
    var overheatProtection: OverheatProtection?
    var overheatTemp: OverheatTemp?
    var bioweaponMode: Bool?
    var batteryHeater: Bool?
    var wiperHeater: Bool?
    var mirrorHeaters: Bool?
}

struct MediaReading: Equatable, Sendable {
    enum SourceKind: Sendable { case bluetooth, radio, streaming, other }

    /// nil when the car didn't say whether it is playing.
    var isPlaying: Bool?
    var title: String?
    var artist: String?
    var album: String?
    var station: String?
    var sourceKind: SourceKind?
    /// Name of the source as the car shows it, such as the paired phone.
    var sourceName: String?
    var volume: Double?
    var volumeMax: Double?
    var elapsedSeconds: Double?
    var durationSeconds: Double?

    var hasTrack: Bool { !(title ?? "").isEmpty || !(station ?? "").isEmpty }
    /// A track is loaded and the car isn't reporting it as stopped.
    var isActive: Bool { hasTrack && isPlaying != nil }
}

struct ClosuresReading: Equatable, Sendable {
    enum Part: Hashable, Sendable, CaseIterable {
        case frontLeftDoor, frontRightDoor, rearLeftDoor, rearRightDoor
        case frunk, trunk
        case frontLeftWindow, frontRightWindow, rearLeftWindow, rearRightWindow
        case sunroof
    }

    enum SentryState: Sendable { case off, idle, armed, aware, panic, quiet }

    var locked: Bool?
    /// Parts the car reports as open.
    var open: Set<Part> = []
    var hasSunroof = false
    var sentry: SentryState?
}

struct TireReading: Equatable, Sendable {
    enum Position: Hashable, Sendable, CaseIterable { case frontLeft, frontRight, rearLeft, rearRight }

    var pressureBar: [Position: Double] = [:]
    var warning: Set<Position> = []
    var recommendedFrontBar: Double?
    var recommendedRearBar: Double?
}

struct LocationReading: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var headingDegrees: Double?
    var placeName: String?
    var homelinkNearby: Bool?
}

enum SoftwareUpdateReading: Equatable, Sendable {
    case none, downloading, available, scheduled, installing
}

/// Everything the UI shows about the car. Only ever filled from vehicle
/// responses (or preview fixtures in DEBUG previews).
struct VehicleReadings: Equatable, Sendable {
    var drive: DriveReading?
    var charge: ChargeReading?
    var climate: ClimateReading?
    var media: MediaReading?
    var closures: ClosuresReading?
    var tires: TireReading?
    var location: LocationReading?
    var softwareUpdate: SoftwareUpdateReading?
}

/// One site from the car's nearby Supercharger query.
struct SuperchargerSite: Identifiable, Equatable, Sendable {
    let id: Int64
    var name: String
    var distanceMiles: Double
    var availableStalls: Int
    var totalStalls: Int
    var isClosed: Bool
    var withinRange: Bool
}

/// What the Tesla BLE path can do, per the lwshanbd fork of swift-tesla-ble
/// and Tesla's vehicle-command protobufs. The UI reads these instead of
/// assuming a control exists.
enum VehicleCapabilities {
    /// `fanStatus` is readable; there is no BLE action to set fan speed or
    /// fan Auto, so the fan is a readout.
    static let fanControl = false
    /// There is no BLE command to close the front trunk.
    static let closeFrunk = false
    /// No album artwork is sent over BLE.
    static let mediaArtwork = false
}
