import SwiftUI

/// Now Playing. Everything comes from the car's media state; there is no
/// artwork over BLE, so the title carries the page.
struct MusicPage: View {
    let model: AppModel
    let layout: PageLayout
    @Environment(\.palette) private var palette

    private var media: MediaReading? { model.media }
    private var isRadio: Bool { media?.sourceKind == .radio }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "NOW PLAYING", onBack: model.closePage) {
                if model.isInGear { HeaderSpeed(value: model.displaySpeed, unit: model.unitLabel) }
            }
            if layout.landscape {
                HStack(spacing: 40) {
                    VStack(spacing: 16) {
                        sourceChip
                        titleBlock
                    }
                    .frame(maxWidth: .infinity)
                    VStack(spacing: 0) {
                        progress
                        transport.padding(.top, 20)
                        Spacer(minLength: 12)
                        VolumeSlider(model: model)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 16)
                .frame(maxHeight: .infinity)
            } else {
                sourceChip.padding(.top, 28)
                Spacer(minLength: 16)
                titleBlock
                progress.padding(.top, 40)
                transport.padding(.top, 28)
                if isRadio {
                    TrackedLabel(text: "FAVORITES", size: 11).padding(.top, 6)
                }
                Spacer(minLength: 16)
                VolumeSlider(model: model)
            }
        }
        .padding(layout.insets)
    }

    @ViewBuilder
    private var sourceChip: some View {
        if let text = sourceText {
            HStack(spacing: 8) {
                Icon(isRadio ? .radio : .phone, size: 16)
                Text(text).font(.system(size: 15)).lineLimit(1)
            }
            .foregroundStyle(palette.text2)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(palette.fill))
        }
    }

    private var sourceText: String? {
        switch media?.sourceKind {
        case .bluetooth?: "\(media?.sourceName ?? "Phone") · Bluetooth"
        case .radio?: media?.sourceName ?? "Radio"
        case .streaming?, .other?: media?.sourceName
        case nil: nil
        }
    }

    private var titleBlock: some View {
        let title = (isRadio ? media?.station : nil) ?? media?.title
        let artist = isRadio && media?.station != nil ? (media?.title ?? media?.artist) : media?.artist
        return VStack(spacing: 8) {
            Text(title.flatMap { $0.isEmpty ? nil : $0 } ?? "Not playing")
                .font(.system(size: 36, weight: .semibold))
                .tracking(-0.54)
                .foregroundStyle(title == nil ? palette.text2 : palette.text)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            if let artist, !artist.isEmpty {
                Text(artist).font(.system(size: 19)).foregroundStyle(palette.text2).padding(.top, 4)
            }
            if let album = media?.album, !album.isEmpty, !isRadio {
                Text(album).font(.system(size: 15)).foregroundStyle(palette.text2)
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var progress: some View {
        if isRadio {
            TrackedLabel(text: "LIVE")
        } else if let duration = media?.durationSeconds, duration > 0, let elapsed = media?.elapsedSeconds {
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
                    Text(Self.time(duration))
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
        HStack(spacing: 32) {
            RoundIconButton(.previous, diameter: 72, iconSize: 30, fill: nil,
                            label: isRadio ? "Previous favorite" : "Previous track") {
                model.mediaAction(isRadio ? .previousFavorite : .previous)
            }
            PlayToggleButton(model: model, diameter: 88, iconSize: 34, fill: palette.fill)
            RoundIconButton(.next, diameter: 72, iconSize: 30, fill: nil,
                            label: isRadio ? "Next favorite" : "Next track") {
                model.mediaAction(isRadio ? .nextFavorite : .next)
            }
        }
    }

    static func time(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Drag or tap to set the car's volume. The value is sent when the finger
/// lifts, so one gesture is one BLE command.
struct VolumeSlider: View {
    let model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        if let reported = model.media?.volume {
            let maximum = max(model.media?.volumeMax ?? 11, 1)
            let volume = model.volumeDraft ?? reported
            let fraction = min(1, max(0, volume / maximum))
            HStack(spacing: 16) {
                Icon(.speaker, size: 22).foregroundStyle(palette.text2)
                GeometryReader { track in
                    let width = track.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.line).frame(height: 6)
                        Capsule().fill(palette.text2).frame(width: width * fraction, height: 6)
                        Circle()
                            .fill(palette.text)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                            .offset(x: width * fraction - 14)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                model.notePageInteraction()
                                let x = min(max(0, value.location.x), width)
                                model.volumeDraft = (x / width * maximum * 2).rounded() / 2
                            }
                            .onEnded { _ in model.commitVolume() }
                    )
                }
                .frame(height: 44)
                .accessibilityElement()
                .accessibilityLabel("Volume")
                .accessibilityValue("\(Int(volume.rounded())) of \(Int(maximum))")
                .accessibilityAdjustableAction { direction in
                    model.mediaAction(direction == .increment ? .volumeUp : .volumeDown)
                }
                Text("\(Int(volume.rounded()))")
                    .font(.system(size: 17, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.text2)
                    .frame(width: 24, alignment: .trailing)
            }
            .frame(height: 52)
        }
    }
}
