import SwiftUI

/// Nearby Superchargers as the car's navigation sees them.
struct ChargersPage: View {
    let model: AppModel
    let layout: PageLayout
    @Environment(\.palette) private var palette

    var body: some View {
        PageScaffold(layout: layout) {
            PageHeader(title: String(localized: "SUPERCHARGERS"), onBack: model.closePage) {
                Button(action: model.refreshSuperchargers) {
                    Group {
                        if model.isLoadingSuperchargers {
                            ProgressView()
                        } else {
                            Icon(.refresh, size: 20)
                        }
                    }
                    .foregroundStyle(palette.text)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(palette.fill))
                }
                .buttonStyle(PressStyle())
                .disabled(model.isLoadingSuperchargers || !model.isLive)
                .accessibilityLabel(String(localized: "Refresh"))
            }
        } content: {
            VStack(spacing: 10) {
                if let sites = model.superchargers {
                    if sites.isEmpty {
                        message(String(localized: "No Superchargers nearby"), String(localized: "The car's navigation didn't list any sites."))
                    } else {
                        ForEach(sites) { site in row(site) }
                        Text(String(localized: "Free stalls"))
                            .font(.system(size: 13))
                            .foregroundStyle(palette.text2)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 4)
                    }
                } else if model.isLoadingSuperchargers {
                    message(String(localized: "Asking the car…"), nil)
                } else {
                    message(model.isLive ? String(localized: "Couldn't get Superchargers") : String(localized: "Not connected"), String(localized: "Tap refresh to ask the car again."))
                }
            }
            .padding(.top, 20)
        }
    }

    private func row(_ site: SuperchargerSite) -> some View {
        let full = site.availableStalls == 0 || site.isClosed
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(site.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(model.distanceLabel(miles: site.distanceMiles))
                    if site.isClosed || !site.withinRange {
                        Text(site.isClosed ? String(localized: "Station closed") : String(localized: "Out of range"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(site.isClosed ? palette.text2 : palette.warn)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(Capsule().fill(palette.pbtn))
                    }
                }
                .font(.system(size: 15))
                .foregroundStyle(palette.text2)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(site.isClosed ? "—" : "\(site.availableStalls)")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(full ? palette.text2 : palette.text)
                Text("/\(site.totalStalls)")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.text2)
            }
            .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 76)
        .panel()
        .opacity(site.isClosed ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(site.name), \(model.distanceLabel(miles: site.distanceMiles)), \(site.isClosed ? String(localized: "Station closed") : String(localized: "\(site.availableStalls) of \(site.totalStalls) stalls free"))"))
    }

    private func message(_ title: String, _ detail: String?) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.text)
            if let detail {
                Text(detail).font(.system(size: 15)).foregroundStyle(palette.text2)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
