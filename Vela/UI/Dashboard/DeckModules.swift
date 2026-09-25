import SwiftUI

/// − temperature + row. Tapping the temperature opens Climate.
struct ClimateModule: View {
    let model: AppModel
    var buttonSize: CGFloat
    var iconSize: CGFloat
    var fontSize: CGFloat
    var labelMinWidth: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        let label = model.temperatureLabel(model.driverSetpointC)
        HStack(spacing: 0) {
            RoundIconButton(.minus, diameter: buttonSize, iconSize: iconSize, label: "Lower temperature") {
                model.adjustDriverTemperature(by: -1)
            }
            Spacer(minLength: 8)
            Button {
                model.open(.climate)
            } label: {
                Text(label)
                    .font(.system(size: fontSize, weight: .regular))
                    .monospacedDigit()
                    .tracking(-0.03 * fontSize)
                    .foregroundStyle(palette.text)
                    .frame(minWidth: labelMinWidth, minHeight: buttonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Climate, set to \(label). Open climate")
            Spacer(minLength: 8)
            RoundIconButton(.plus, diameter: buttonSize, iconSize: iconSize, label: "Raise temperature") {
                model.adjustDriverTemperature(by: 1)
            }
        }
    }
}

/// Play/pause button: shows pause while playing and play otherwise. If the
/// car didn't report playback status, it shows both glyphs.
struct PlayToggleButton: View {
    let model: AppModel
    let diameter: CGFloat
    let iconSize: CGFloat

    var body: some View {
        let (icon, label): (VelaIcon, String) = switch model.media?.isPlaying {
        case true?: (.pause, "Pause")
        case false?: (.play, "Play")
        case nil: (.playPause, "Play or pause")
        }
        RoundIconButton(icon, diameter: diameter, iconSize: iconSize, label: label) {
            model.mediaAction(.togglePlayback)
        }
    }
}

struct TransportRow: View {
    let model: AppModel
    var skipSize: CGFloat
    var skipIcon: CGFloat
    var playSize: CGFloat
    var playIcon: CGFloat
    /// nil: spread across the width (landscape deck).
    var spacing: CGFloat?

    var body: some View {
        HStack(spacing: spacing ?? 0) {
            RoundIconButton(.previous, diameter: skipSize, iconSize: skipIcon, filled: false, label: "Previous track") {
                model.mediaAction(.previous)
            }
            if spacing == nil { Spacer(minLength: 0) }
            PlayToggleButton(model: model, diameter: playSize, iconSize: playIcon)
            if spacing == nil { Spacer(minLength: 0) }
            RoundIconButton(.next, diameter: skipSize, iconSize: skipIcon, filled: false, label: "Next track") {
                model.mediaAction(.next)
            }
        }
    }
}

/// Portrait media module: one-line title — artist, then transport.
struct PortraitMediaModule: View {
    let model: AppModel
    var compact: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 12) {
            Button {
                model.open(.music)
            } label: {
                (Text(model.media?.title ?? "").fontWeight(.semibold).foregroundColor(palette.text)
                    + Text(artistSuffix).foregroundColor(palette.text2))
                    .font(.system(size: 17))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Now Playing")
            TransportRow(
                model: model,
                skipSize: compact ? 56 : 64, skipIcon: 26,
                playSize: compact ? 64 : 72, playIcon: 28,
                spacing: compact ? 27 : 36
            )
        }
    }

    private var artistSuffix: String {
        guard let artist = model.media?.artist, !artist.isEmpty else { return "" }
        return "\u{00A0}— \(artist)"
    }
}

/// Landscape media module: artwork well, two lines, transport below.
struct LandscapeMediaModule: View {
    let model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 22) {
            Button {
                model.open(.music)
            } label: {
                HStack(spacing: 14) {
                    Icon(.note, size: 22)
                        .foregroundStyle(palette.text3)
                        .frame(width: 56, height: 56)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.fill))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.media?.title ?? "")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(palette.text)
                        if let artist = model.media?.artist, !artist.isEmpty {
                            Text(artist)
                                .font(.system(size: 15))
                                .foregroundStyle(palette.text2)
                        }
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Now Playing")
            TransportRow(model: model, skipSize: 60, skipIcon: 24, playSize: 68, playIcon: 26, spacing: nil)
                .padding(.horizontal, 18)
        }
    }
}
