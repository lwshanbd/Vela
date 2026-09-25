import MapKit
import SwiftUI

private struct PanelBackground: ViewModifier {
    @Environment(\.palette) private var palette
    func body(content: Content) -> some View {
        content.background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.panel))
    }
}

extension View {
    func panel() -> some View { modifier(PanelBackground()) }
}

/// Parked: Controls and Chargers.
struct EntriesPanel: View {
    let context: DashContext
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            entry(.lock, "Controls", "Locks, trunks, windows") { context.model.open(.controls) }
            entry(.bolt, "Chargers", "Nearby Superchargers") { context.model.open(.chargers) }
        }
        .frame(height: context.layout.entriesHeight)
    }

    private func entry(_ glyph: VelaGlyph, _ title: String, _ subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Icon(glyph, size: 22).foregroundStyle(palette.text)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.text)
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(palette.text2).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.panel))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

/// Destination, distance left, minutes to arrival and traffic delay.
struct NavPanel: View {
    let context: DashContext
    @Environment(\.palette) private var palette

    var body: some View {
        let model = context.model
        let route = model.route
        HStack(spacing: 14) {
            Icon(.flag, size: 20).foregroundStyle(palette.text2)
            VStack(alignment: .leading, spacing: 2) {
                Text(route?.destination ?? "–")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                if let miles = route?.milesToArrival {
                    Text(model.distanceLabel(miles: miles))
                        .font(.system(size: 15))
                        .foregroundStyle(palette.text2)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                if let minutes = route?.minutesToArrival {
                    Text(model.minutesLabel(minutes))
                        .font(.system(size: context.layout.arrangement == .row ? 20 : 22, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.text)
                }
                if let delay = route?.trafficDelayMinutes, delay >= 1 {
                    Text("+\(model.minutesLabel(delay))")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.text2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: context.layout.navHeight)
        .panel()
        .accessibilityElement(children: .combine)
    }
}

/// The car's position on a map when online; a compass and the place name
/// when there is no internet for map tiles.
struct MapPanel: View {
    let context: DashContext
    @Environment(\.palette) private var palette

    var body: some View {
        let model = context.model
        let tint = model.settings.tint.color(dark: palette.isDark)
        ZStack(alignment: .bottomLeading) {
            if model.network.isOnline, let location = model.location {
                let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                Map(
                    position: .constant(.camera(MapCamera(centerCoordinate: coordinate, distance: 1400))),
                    interactionModes: []
                ) {
                    Annotation("", coordinate: coordinate, anchor: .center) {
                        Icon(.navArrow, size: 18)
                            .foregroundStyle(tint)
                            .rotationEffect(.degrees(location.headingDegrees ?? 0))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(palette.bg))
                            .overlay(Circle().strokeBorder(palette.line, lineWidth: 1.5))
                    }
                }
                .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
                .environment(\.colorScheme, palette.isDark ? .dark : .light)
                .allowsHitTesting(false)
                if let place = location.placeName {
                    Text(place)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.text2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(palette.panel.opacity(0.85)))
                        .padding(10)
                }
            } else {
                HStack(spacing: 20) {
                    ZStack(alignment: .top) {
                        Circle().strokeBorder(palette.line, lineWidth: 1.5)
                        Text("N")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.text2)
                            .padding(.top, 5)
                        Icon(.navArrow, size: 30)
                            .foregroundStyle(tint)
                            .rotationEffect(.degrees(model.headingDegrees ?? 0))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.headingLabel ?? "–")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(palette.text)
                        if let place = model.location?.placeName {
                            Text(place).font(.system(size: 15)).foregroundStyle(palette.text2).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .frame(maxHeight: .infinity)
            }
        }
        .frame(height: context.layout.mapHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .panel()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heading \(model.headingLabel ?? "unknown")")
    }
}

/// − temperature + in a panel. Tapping the temperature opens Climate.
struct ClimatePanel: View {
    let context: DashContext
    @Environment(\.palette) private var palette

    var body: some View {
        let model = context.model
        let layout = context.layout
        let label = model.temperatureLabel(model.driverSetpointC)
        HStack(spacing: 0) {
            RoundIconButton(.minus, diameter: layout.climateButton, iconSize: 26, fill: palette.pbtn, label: "Lower temperature") {
                model.adjustDriverTemperature(by: -1)
            }
            Spacer(minLength: 4)
            Button {
                model.open(.climate)
            } label: {
                Text(label)
                    .font(.system(size: layout.climateFont, weight: .regular))
                    .monospacedDigit()
                    .tracking(-0.03 * layout.climateFont)
                    .foregroundStyle(palette.text)
                    .frame(minWidth: 110, minHeight: layout.climateButton)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Climate, set to \(label). Open climate")
            Spacer(minLength: 4)
            RoundIconButton(.plus, diameter: layout.climateButton, iconSize: 26, fill: palette.pbtn, label: "Raise temperature") {
                model.adjustDriverTemperature(by: 1)
            }
        }
        .padding(8)
        .panel()
    }
}

/// Play/pause: pause while playing, play otherwise, both glyphs when the car
/// doesn't say.
struct PlayToggleButton: View {
    let model: AppModel
    let diameter: CGFloat
    let iconSize: CGFloat
    let fill: Color

    var body: some View {
        let (glyph, label): (VelaGlyph, String) = switch model.media?.isPlaying {
        case true?: (.pause, "Pause")
        case false?: (.play, "Play")
        case nil: (.playPause, "Play or pause")
        }
        RoundIconButton(glyph, diameter: diameter, iconSize: iconSize, fill: fill, label: label) {
            model.mediaAction(.togglePlayback)
        }
    }
}

/// Track line and transport controls in a panel.
struct MediaPanel: View {
    let context: DashContext
    @Environment(\.palette) private var palette

    var body: some View {
        let model = context.model
        let layout = context.layout
        let radio = model.media?.sourceKind == .radio
        VStack(spacing: 6) {
            Button {
                model.open(.music)
            } label: {
                HStack(spacing: 10) {
                    Icon(radio ? .radio : .note, size: 16).foregroundStyle(palette.text2)
                    (Text(primaryLine).fontWeight(.semibold).foregroundColor(palette.text)
                        + Text(secondaryLine).foregroundColor(palette.text2))
                        .font(.system(size: 17))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Now Playing")
            HStack(spacing: layout.transportGap) {
                RoundIconButton(.previous, diameter: layout.skipSize, iconSize: 24, fill: nil,
                                label: radio ? "Previous favorite" : "Previous track") {
                    model.mediaAction(radio ? .previousFavorite : .previous)
                }
                PlayToggleButton(model: model, diameter: layout.playSize, iconSize: 26, fill: palette.pbtn)
                RoundIconButton(.next, diameter: layout.skipSize, iconSize: 24, fill: nil,
                                label: radio ? "Next favorite" : "Next track") {
                    model.mediaAction(radio ? .nextFavorite : .next)
                }
            }
        }
        .padding(.top, 14)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .panel()
    }

    private var primaryLine: String {
        let media = context.model.media
        return media?.title.flatMap { $0.isEmpty ? nil : $0 } ?? media?.station ?? "–"
    }

    private var secondaryLine: String {
        guard let artist = context.model.media?.artist, !artist.isEmpty else { return "" }
        return "\u{00A0}· \(artist)"
    }
}
