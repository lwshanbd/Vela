import SwiftUI

/// Tire pressures on a top view of the car, and everything open or low.
struct VehiclePage: View {
    let model: AppModel
    let layout: PageLayout
    @Environment(\.palette) private var palette

    private var psi: Bool { model.settings.pressureUnit == .psi }

    var body: some View {
        PageScaffold(layout: layout) {
            PageHeader(title: "VEHICLE", onBack: model.closePage) {
                Segmented(
                    options: [(PressureUnit.bar, "bar"), (.psi, "psi")],
                    selection: model.settings.pressureUnit,
                    accessibilityLabel: "Pressure unit",
                    height: 36
                ) { model.settings.pressureUnit = $0 }
                    .frame(width: 88)
            }
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                carDiagram
                    .frame(height: min(459, layout.landscape ? 360 : layout.contentHeight * 0.58))
                    .padding(.top, 16)
                if let recommended = recommendedText {
                    Text(recommended).font(.system(size: 13)).foregroundStyle(palette.text2).padding(.top, 20)
                }
                Hairline().padding(.top, 12)
                ForEach(Array(model.issues.enumerated()), id: \.offset) { _, issue in
                    HStack(spacing: 12) {
                        Icon(issue.glyph, size: 20).foregroundStyle(palette.warn)
                        Text(issue.text).font(.system(size: 17)).foregroundStyle(palette.text)
                        Spacer()
                    }
                    .frame(minHeight: 48)
                    .overlay(alignment: .bottom) { Hairline() }
                }
                if model.issues.isEmpty, model.closures != nil {
                    Text("All closed")
                        .font(.system(size: 17))
                        .foregroundStyle(palette.text2)
                        .frame(minHeight: 48)
                }
            }
        }
    }

    private func pressure(_ bar: Double?) -> String {
        guard let bar else { return "–" }
        return psi ? "\(Int((bar * 14.5038).rounded()))" : String(format: "%.1f", bar)
    }

    private var recommendedText: String? {
        guard let front = model.tires?.recommendedFrontBar else { return nil }
        let rear = model.tires?.recommendedRearBar
        let unit = psi ? "psi" : "bar"
        if let rear, pressure(rear) != pressure(front) {
            return "Recommended \(pressure(front)) front, \(pressure(rear)) rear \(unit)"
        }
        return "Recommended \(pressure(front)) \(unit)"
    }

    private var carDiagram: some View {
        let tires = model.tires
        let low = model.tireWarnings
        let open = model.openParts
        let palette = palette
        return GeometryReader { proxy in
            let scale = min(proxy.size.width / 345, proxy.size.height / 470)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    context.scaleBy(x: scale, y: scale)
                    context.translateBy(x: (proxy.size.width / scale - 345) / 2, y: 0)
                    func stroke(_ d: String, _ color: Color, _ width: CGFloat) {
                        context.stroke(SVGPath.parse(d), with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                    }
                    stroke("M158 40h29a46 46 0 0 1 46 46v298a46 46 0 0 1-46 46h-29a46 46 0 0 1-46-46V86a46 46 0 0 1 46-46z", palette.text2, 2)
                    stroke("M124 150 Q 172 128 221 150 L 214 178 Q 172 164 131 178 Z", palette.text3, 1.5)
                    stroke("M142 186h61a10 10 0 0 1 10 10v110a10 10 0 0 1-10 10h-61a10 10 0 0 1-10-10V196a10 10 0 0 1 10-10z", palette.text3, 1.5)
                    stroke("M131 326 Q 172 338 214 326 L 220 352 Q 172 366 125 352 Z", palette.text3, 1.5)
                    stroke("M112 250 H 120 M 225 250 H 233", palette.text3, 1.5)
                    let tireRects: [(TireReading.Position, CGRect)] = [
                        (.frontLeft, CGRect(x: 98, y: 104, width: 14, height: 48)),
                        (.frontRight, CGRect(x: 233, y: 104, width: 14, height: 48)),
                        (.rearLeft, CGRect(x: 98, y: 322, width: 14, height: 48)),
                        (.rearRight, CGRect(x: 233, y: 322, width: 14, height: 48)),
                    ]
                    for (position, rect) in tireRects {
                        context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(low.contains(position) ? palette.warn : palette.text2))
                    }
                    let marks: [(ClosuresReading.Part, String, CGFloat)] = [
                        (.frontLeftDoor, "M113 188 V 238", 4), (.rearLeftDoor, "M113 262 V 312", 4),
                        (.frontRightDoor, "M232 188 V 238", 4), (.rearRightDoor, "M232 262 V 312", 4),
                        (.trunk, "M134 430 L 128 458 H 217 L 211 430", 2),
                        (.frunk, "M134 40 L 128 12 H 217 L 211 40", 2),
                        (.frontLeftWindow, "M126 190 V 236", 3), (.rearLeftWindow, "M126 264 V 310", 3),
                        (.frontRightWindow, "M219 190 V 236", 3), (.rearRightWindow, "M219 264 V 310", 3),
                        (.sunroof, "M142 196h61v40h-61z", 2),
                    ]
                    for (part, d, width) in marks where open.contains(part) {
                        stroke(d, palette.warn, width)
                    }
                }
                TrackedLabel(text: "FRONT")
                tireLabel(.frontLeft, tires, low, y: 108 * scale, leading: true)
                tireLabel(.frontRight, tires, low, y: 108 * scale, leading: false)
                tireLabel(.rearLeft, tires, low, y: 326 * scale, leading: true)
                tireLabel(.rearRight, tires, low, y: 326 * scale, leading: false)
            }
        }
    }

    private func tireLabel(
        _ position: TireReading.Position, _ tires: TireReading?, _ low: Set<TireReading.Position>,
        y: CGFloat, leading: Bool
    ) -> some View {
        let isLow = low.contains(position)
        let unit = psi ? "psi" : "bar"
        return VStack(alignment: leading ? .leading : .trailing, spacing: 2) {
            Text(pressure(tires?.pressureBar[position]))
                .font(.system(size: 28, weight: .semibold))
                .monospacedDigit()
            Text(isLow ? "\(unit) · Low" : unit)
                .font(.system(size: 13, weight: isLow ? .semibold : .regular))
        }
        .foregroundStyle(isLow ? palette.warn : palette.text)
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
        .offset(y: y)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(AppModel.name(of: position)) tire \(pressure(tires?.pressureBar[position])) \(unit)\(isLow ? ", low" : "")")
    }
}
