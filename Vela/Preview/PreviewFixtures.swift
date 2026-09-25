#if DEBUG
import SwiftUI

/// Sample data for SwiftUI previews and the DEBUG `-VelaFixtures` launch
/// argument. Compiled into DEBUG builds only; the production path fills
/// readings exclusively from vehicle responses.
enum PreviewFixtures {
    static let identity = VehicleIdentity(vin: "7SAYGDEE0PA000001")

    static let climate = ClimateReading(
        isOn: true, driverSetpointC: 21.1, passengerSetpointC: 21.1, insideC: 20, outsideC: 12, fanLevel: 4,
        seatHeat: [.frontLeft: 2, .frontRight: 0, .rearLeft: 0, .rearCenter: 0, .rearRight: 1],
        seatCool: [.frontLeft: 0, .frontRight: 1],
        steeringWheelHeat: true, autoSeatClimate: false, frontDefroster: false, rearDefroster: true,
        maxDefrost: false, keeperMode: .off, overheatProtection: .fanOnly, overheatTemp: .medium,
        bioweaponMode: false, batteryHeater: true, wiperHeater: false, mirrorHeaters: false
    )

    static let media = MediaReading(
        isPlaying: true, title: "Midnight Run", artist: "The Halden Line", album: "Low Lights",
        sourceKind: .bluetooth, sourceName: "iPhone", volume: 6, volumeMax: 10,
        elapsedSeconds: 84, durationSeconds: 221
    )

    static let charge = ChargeReading(batteryLevel: 78, ratedRangeMiles: 212, status: .disconnected, limitPercent: 80)

    static let driving = VehicleReadings(
        drive: DriveReading(
            speedMph: 47, gear: .drive, powerKW: 38,
            route: RouteReading(destination: "Millbrook Plaza", minutesToArrival: 18, milesToArrival: 12, trafficDelayMinutes: 4)
        ),
        charge: charge,
        climate: climate,
        media: media,
        closures: ClosuresReading(locked: true, hasSunroof: true, sentry: .off),
        tires: TireReading(
            pressureBar: [.frontLeft: 2.9, .frontRight: 2.9, .rearLeft: 2.8, .rearRight: 2.9],
            recommendedFrontBar: 2.9, recommendedRearBar: 2.9
        ),
        location: LocationReading(latitude: 37.7599, longitude: -122.4148, headingDegrees: 42, placeName: "Mission District", homelinkNearby: true)
    )

    static var drivingWithAlerts: VehicleReadings {
        var readings = driving
        readings.tires?.pressureBar[.frontRight] = 2.3
        readings.tires?.warning = [.frontRight]
        readings.closures?.open = [.trunk, .rearLeftWindow]
        return readings
    }

    static var parked: VehicleReadings {
        var readings = drivingWithAlerts
        readings.drive = DriveReading(speedMph: nil, gear: .park, powerKW: 0)
        readings.media?.isPlaying = false
        readings.softwareUpdate = .available
        return readings
    }

    static var charging: VehicleReadings {
        var readings = parked
        readings.charge = ChargeReading(
            batteryLevel: 64, ratedRangeMiles: 196, status: .charging, limitPercent: 80,
            minutesToLimit: 32, minutesToFull: 70, powerKW: 148, voltage: 402, currentAmps: 368,
            energyAddedKWh: 28.4, isFastCharger: true, portOpen: true
        )
        return readings
    }

    static let superchargers = [
        SuperchargerSite(id: 1, name: "Harbor Point", distanceMiles: 2.4, availableStalls: 6, totalStalls: 12, isClosed: false, withinRange: true),
        SuperchargerSite(id: 2, name: "Millbrook Plaza", distanceMiles: 5.1, availableStalls: 3, totalStalls: 16, isClosed: false, withinRange: true),
        SuperchargerSite(id: 3, name: "Crestview Commons", distanceMiles: 9.8, availableStalls: 0, totalStalls: 8, isClosed: false, withinRange: true),
        SuperchargerSite(id: 4, name: "Old Mill Road", distanceMiles: 18, availableStalls: 0, totalStalls: 10, isClosed: true, withinRange: true),
        SuperchargerSite(id: 5, name: "Lakeside Junction", distanceMiles: 214, availableStalls: 10, totalStalls: 20, isClosed: false, withinRange: false),
    ]

    static var allModules: DashboardConfig {
        var config = DashboardConfig.default
        for index in config.portrait.indices where config.portrait[index].module != .map {
            config.portrait[index].isOn = true
        }
        for index in config.landscape.indices where config.landscape[index].module != .map {
            config.landscape[index].isOn = true
        }
        return config
    }
}

#Preview("Driving") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.driving))
}

#Preview("Driving · alerts", traits: .landscapeLeft) {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.drivingWithAlerts))
}

#Preview("Parked") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.parked))
        .preferredColorScheme(.light)
}

#Preview("Asleep") {
    RootView(model: .preview(link: .asleep, readings: VehicleReadings()))
}

#Preview("Charging") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.charging, page: .charging))
}

#Preview("Climate") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.parked, page: .climate))
}

#Preview("Controls") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.parked, page: .controls))
}

#Preview("Superchargers") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.parked, page: .chargers))
}

#Preview("Vehicle") {
    RootView(model: .preview(link: .connected, readings: PreviewFixtures.parked, page: .vehicle))
}

#Preview("Setup · VIN") {
    RootView(model: .preview(link: .idle, readings: VehicleReadings(), onboarding: .enterVIN(expectedLocalName: nil)))
}
#endif
