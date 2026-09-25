import Foundation

/// UI-facing connection state. Independent of TeslaBLE's enum so views never
/// see protocol types.
enum LinkState: Equatable, Sendable {
    /// No paired vehicle, or the app is in the background.
    case idle
    /// First connect since launch/foreground: scanning, BLE connect, handshake.
    case connecting
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

struct DriveReading: Equatable, Sendable {
    /// As reported by the car. `nil` when the car didn't include a speed.
    var speedMph: Double?
    var gear: Gear?
}

struct ClimateReading: Equatable, Sendable {
    var isOn: Bool
    var driverSetpointC: Double
    var passengerSetpointC: Double
    /// Fan level as reported by the car. Read-only over BLE.
    var fanLevel: Int?
}

struct MediaReading: Equatable, Sendable {
    /// nil when the car didn't say whether it is playing.
    var isPlaying: Bool?
    var title: String?
    var artist: String?
    var volume: Double?
    var volumeMax: Double?
    var elapsedSeconds: Double?
    var durationSeconds: Double?

    var hasTrack: Bool { !(title ?? "").isEmpty }
}

/// Everything the UI shows about the car. Only ever filled from vehicle
/// responses (or preview fixtures in DEBUG previews).
struct VehicleReadings: Equatable, Sendable {
    var drive: DriveReading?
    var batteryLevel: Int?
    var climate: ClimateReading?
    var media: MediaReading?
}

/// What the Tesla BLE path can actually do, per swift-tesla-ble and Tesla's
/// vehicle-command CarServer protobufs. The UI reads these flags instead of
/// assuming a control exists.
enum VehicleCapabilities {
    // Climate: `.climate(.on/.off)`, `.climate(.setTemperature(driver:passenger:))`,
    // ClimateState.isClimateOn / driver+passenger setpoints / fanStatus.
    static let climatePower = true
    static let climateTemperature = true
    /// `fanStatus` is readable; there is no BLE action to set fan speed or
    /// toggle fan Auto, so those controls are not shown.
    static let fanReadout = true
    static let fanControl = false

    // Media: `.media(.togglePlayback/.nextTrack/.previousTrack/.volumeUp/.volumeDown)`,
    // MediaState title/artist/volume, MediaDetailState elapsed/duration.
    static let mediaTransport = true
    static let mediaVolume = true
    static let mediaMetadata = true
    /// `MediaState.playbackStatus` (added in the lwshanbd fork). When a car
    /// omits it, the play button falls back to a combined play/pause glyph.
    static let mediaPlaybackStatus = true
    /// No album artwork is sent over BLE.
    static let mediaArtwork = false
}
