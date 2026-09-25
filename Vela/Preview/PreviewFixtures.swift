#if DEBUG
import SwiftUI

/// Sample data for SwiftUI previews. Compiled into DEBUG builds only and
/// reachable only through `AppModel.preview`; the production path fills
/// readings exclusively from vehicle responses.
enum PreviewFixtures {
    static let identity = VehicleIdentity(vin: "7SAYGDEE0PA000001")

    static let driving = VehicleReadings(
        drive: DriveReading(speedMph: 47, gear: .drive),
        batteryLevel: 78,
        climate: ClimateReading(isOn: true, driverSetpointC: 21.1, passengerSetpointC: 21.1, fanLevel: 4),
        media: MediaReading(
            isPlaying: true,
            title: "Midnight Run", artist: "The Halden Line",
            volume: 6, volumeMax: 10, elapsedSeconds: 84, durationSeconds: 221
        )
    )

    static let parked = VehicleReadings(
        drive: DriveReading(speedMph: nil, gear: .park),
        batteryLevel: 78,
        climate: driving.climate,
        media: driving.media
    )

    static let instrumentOnly = VehicleReadings(
        drive: DriveReading(speedMph: 47, gear: .drive),
        batteryLevel: 78
    )
}

#Preview("Dashboard · Portrait · Dark") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.driving))
        .preferredColorScheme(.dark)
}

#Preview("Dashboard · Portrait · Light") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.driving))
        .preferredColorScheme(.light)
}

#Preview("Dashboard · Landscape", traits: .landscapeLeft) {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.driving))
        .preferredColorScheme(.dark)
}

#Preview("Dashboard · Connecting") {
    RootView(model: .preview(link: .connecting, readings: VehicleReadings()))
}

#Preview("Dashboard · Lost", traits: .landscapeLeft) {
    RootView(model: .preview(link: .lost, readings: PreviewFixtures.driving))
}

#Preview("Dashboard · Instrument only") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.instrumentOnly))
}

#Preview("Now Playing") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.parked, page: .music))
}

#Preview("Climate") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.parked, page: .climate))
        .preferredColorScheme(.light)
}

#Preview("Settings") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.parked, page: .settings))
}

#Preview("Setup · Welcome") {
    RootView(model: .preview(link: .idle, readings: VehicleReadings(), onboarding: .welcome))
}

#Preview("Pairing · Confirm") {
    RootView(model: .preview(
        link: .idle, readings: VehicleReadings(),
        onboarding: .confirmInCar(PreviewFixtures.identity)
    ))
}
#endif
