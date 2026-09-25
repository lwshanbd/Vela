import SwiftUI

/// Now Playing. Title, artist, progress and volume come from the car's media
/// state; there is no artwork over BLE, so the well shows the note glyph.
struct MusicPage: View {
    let model: AppModel
    let layout: PageLayout
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "NOW PLAYING", speed: (model.displaySpeed, model.unitLabel)) {
                model.closePage()
            }
            if layout.landscape {
                landscapeBody
            } else {
                portraitBody
            }
        }
        .padding(layout.insets)
    }

    private var portraitBody: some View {
        let art = min(layout.contentWidth * 0.86, layout.contentHeight * 0.4)
        return VStack(spacing: 0) {
            artwork(size: art)
                .padding(.top, layout.contentHeight < 640 ? 20 : 36)
            titleBlock(alignment: .center)
                .padding(.top, 32)
            progress
                .padding(.top, 26)
            transport
                .padding(.top, 22)
            Spacer(minLength: 16)
            volume
        }
    }

    private var landscapeBody: some View {
        let art = min(layout.contentHeight - 44 - 24, layout.contentWidth * 0.4)
        return HStack(spacing: 40) {
            artwork(size: art)
            VStack(spacing: 0) {
                titleBlock(alignment: .leading)
                progress.padding(.top, 18)
                transport.padding(.top, 14)
                Spacer(minLength: 8)
                volume
            }
            .frame(maxHeight: art)
        }
        .frame(maxHeight: .infinity)
    }

    private func artwork(size: CGFloat) -> some View {
        Icon(.note, size: 48, lineWidth: 1.2)
            .foregroundStyle(palette.text3)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.art))
            .accessibilityHidden(true)
    }

    private func titleBlock(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(model.media?.hasTrack == true ? (model.media?.title ?? "") : "Not playing")
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.26)
                .foregroundStyle(model.media?.hasTrack == true ? palette.text : palette.text2)
            if let artist = model.media?.artist, !artist.isEmpty {
                Text(artist)
                    .font(.system(size: 17))
                    .foregroundStyle(palette.text2)
            }
        }
        .lineLimit(1)
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }

    @ViewBuilder
    private var progress: some View {
        if let duration = model.media?.durationSeconds, duration > 0,
           let elapsed = model.media?.elapsedSeconds
        {
            VStack(spacing: 8) {
                GeometryReader { bar in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.line)
                        Capsule().fill(palette.text2)
                            .frame(width: bar.size.width * min(1, max(0, elapsed / duration)))
                    }
                }
                .frame(height: 3)
                HStack {
                    Text(Self.time(elapsed))
                    Spacer()
                    Text("-" + Self.time(max(0, duration - elapsed)))
                }
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(palette.text2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Self.time(elapsed)) of \(Self.time(duration))")
        }
    }

    private var transport: some View {
        TransportRow(model: model, skipSize: 72, skipIcon: 30, playSize: 88, playIcon: 34, spacing: 32)
    }

    @ViewBuilder
    private var volume: some View {
        if let level = model.media?.volume {
            let maximum = max(model.media?.volumeMax ?? 11, 1)
            HStack(spacing: 16) {
                RoundIconButton(.volumeDown, diameter: 52, iconSize: 22, foreground: palette.text2, label: "Volume down") {
                    model.mediaAction(.volumeDown)
                }
                GeometryReader { bar in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.line)
                        Capsule().fill(palette.text2)
                            .frame(width: bar.size.width * min(1, max(0, level / maximum)))
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 4)
                .accessibilityElement()
                .accessibilityLabel("Volume")
                .accessibilityValue("\(Int((level / maximum * 100).rounded())) percent")
                RoundIconButton(.volumeUp, diameter: 52, iconSize: 22, foreground: palette.text2, label: "Volume up") {
                    model.mediaAction(.volumeUp)
                }
            }
        }
    }

    private static func time(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
