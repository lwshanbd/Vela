import SwiftUI

/// Parses SVG path data (`d` attribute) into a SwiftUI `Path`, so icons are
/// drawn from the design's own path strings. Supports M L H V C S Q T A Z in
/// absolute and relative form.
enum SVGPath {
    static func parse(_ data: String) -> Path {
        var parser = Parser(data)
        return parser.run()
    }

    private struct Parser {
        let scalars: [Character]
        var index = 0
        var path = Path()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControl: CGPoint?
        var lastCommand: Character = " "

        init(_ data: String) {
            scalars = Array(data)
        }

        mutating func run() -> Path {
            var command: Character = "M"
            while true {
                skipSeparators()
                guard index < scalars.count else { break }
                let c = scalars[index]
                if c.isLetter, c != "e", c != "E" {
                    command = c
                    index += 1
                } else if command == "M" {
                    command = "L"
                } else if command == "m" {
                    command = "l"
                }
                if !apply(command) { break }
                lastCommand = command
            }
            return path
        }

        mutating func skipSeparators() {
            while index < scalars.count, scalars[index] == " " || scalars[index] == "," || scalars[index].isNewline {
                index += 1
            }
        }

        mutating func number() -> CGFloat? {
            skipSeparators()
            guard index < scalars.count else { return nil }
            var text = ""
            var seenDot = false
            var seenExp = false
            if scalars[index] == "-" || scalars[index] == "+" {
                text.append(scalars[index])
                index += 1
            }
            while index < scalars.count {
                let c = scalars[index]
                if c.isNumber {
                    text.append(c)
                } else if c == ".", !seenDot, !seenExp {
                    seenDot = true
                    text.append(c)
                } else if c == "e" || c == "E", !seenExp {
                    seenExp = true
                    text.append(c)
                    if index + 1 < scalars.count, scalars[index + 1] == "-" || scalars[index + 1] == "+" {
                        index += 1
                        text.append(scalars[index])
                    }
                } else {
                    break
                }
                index += 1
            }
            return Double(text).map { CGFloat($0) }
        }

        /// Arc flags may be written without separators ("0 1 0" or "010").
        mutating func flag() -> Bool? {
            skipSeparators()
            guard index < scalars.count else { return nil }
            let c = scalars[index]
            guard c == "0" || c == "1" else { return nil }
            index += 1
            return c == "1"
        }

        mutating func point(relative: Bool) -> CGPoint? {
            guard let x = number(), let y = number() else { return nil }
            return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        }

        mutating func apply(_ command: Character) -> Bool {
            let relative = command.isLowercase
            switch command.uppercased().first! {
            case "M":
                guard let p = point(relative: relative) else { return false }
                path.move(to: p)
                current = p
                subpathStart = p
                lastControl = nil
            case "L":
                guard let p = point(relative: relative) else { return false }
                path.addLine(to: p)
                current = p
                lastControl = nil
            case "H":
                guard let x = number() else { return false }
                current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
                lastControl = nil
            case "V":
                guard let y = number() else { return false }
                current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                path.addLine(to: current)
                lastControl = nil
            case "C":
                guard let c1 = point(relative: relative), let c2 = point(relative: relative),
                      let p = point(relative: relative) else { return false }
                path.addCurve(to: p, control1: c1, control2: c2)
                lastControl = c2
                current = p
            case "S":
                let c1 = reflected(for: "CS")
                guard let c2 = point(relative: relative), let p = point(relative: relative) else { return false }
                path.addCurve(to: p, control1: c1, control2: c2)
                lastControl = c2
                current = p
            case "Q":
                guard let c = point(relative: relative), let p = point(relative: relative) else { return false }
                path.addQuadCurve(to: p, control: c)
                lastControl = c
                current = p
            case "T":
                let c = reflected(for: "QT")
                guard let p = point(relative: relative) else { return false }
                path.addQuadCurve(to: p, control: c)
                lastControl = c
                current = p
            case "A":
                guard let rx = number(), let ry = number(), let rotation = number(),
                      let large = flag(), let sweep = flag(), let p = point(relative: relative)
                else { return false }
                addArc(to: p, rx: rx, ry: ry, rotation: rotation, large: large, sweep: sweep)
                current = p
                lastControl = nil
            case "Z":
                path.closeSubpath()
                current = subpathStart
                lastControl = nil
            default:
                return false
            }
            return true
        }

        func reflected(for commands: String) -> CGPoint {
            guard let control = lastControl, commands.contains(lastCommand.uppercased().first!) else { return current }
            return CGPoint(x: 2 * current.x - control.x, y: 2 * current.y - control.y)
        }

        /// SVG endpoint arc to cubic Béziers (SVG spec, appendix F.6).
        mutating func addArc(to end: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat, rotation: CGFloat, large: Bool, sweep: Bool) {
            var rx = abs(rxIn), ry = abs(ryIn)
            let start = current
            guard rx > 0, ry > 0, start != end else {
                path.addLine(to: end)
                return
            }
            let phi = rotation * .pi / 180
            let cosPhi = cos(phi), sinPhi = sin(phi)
            let dx = (start.x - end.x) / 2, dy = (start.y - end.y) / 2
            let x1p = cosPhi * dx + sinPhi * dy
            let y1p = -sinPhi * dx + cosPhi * dy
            let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
            if lambda > 1 {
                rx *= sqrt(lambda)
                ry *= sqrt(lambda)
            }
            let numerator = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
            let denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p
            var coefficient = sqrt(max(0, numerator / denominator))
            if large == sweep { coefficient = -coefficient }
            let cxp = coefficient * rx * y1p / ry
            let cyp = -coefficient * ry * x1p / rx
            let cx = cosPhi * cxp - sinPhi * cyp + (start.x + end.x) / 2
            let cy = sinPhi * cxp + cosPhi * cyp + (start.y + end.y) / 2

            func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
                let sign: CGFloat = ux * vy - uy * vx < 0 ? -1 : 1
                let dot = (ux * vx + uy * vy) / (sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy))
                return sign * acos(min(1, max(-1, dot)))
            }
            let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
            var delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
            if !sweep, delta > 0 { delta -= 2 * .pi }
            if sweep, delta < 0 { delta += 2 * .pi }

            let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
            let step = delta / CGFloat(segments)
            let k = 4 / 3 * tan(step / 4)
            var theta = theta1
            func pointOnEllipse(_ t: CGFloat) -> CGPoint {
                CGPoint(
                    x: cx + rx * cos(t) * cosPhi - ry * sin(t) * sinPhi,
                    y: cy + rx * cos(t) * sinPhi + ry * sin(t) * cosPhi
                )
            }
            func derivative(_ t: CGFloat) -> CGPoint {
                CGPoint(
                    x: -rx * sin(t) * cosPhi - ry * cos(t) * sinPhi,
                    y: -rx * sin(t) * sinPhi + ry * cos(t) * cosPhi
                )
            }
            for _ in 0 ..< segments {
                let t2 = theta + step
                let p1 = pointOnEllipse(theta), p2 = pointOnEllipse(t2)
                let d1 = derivative(theta), d2 = derivative(t2)
                path.addCurve(
                    to: p2,
                    control1: CGPoint(x: p1.x + k * d1.x, y: p1.y + k * d1.y),
                    control2: CGPoint(x: p2.x - k * d2.x, y: p2.y - k * d2.y)
                )
                theta = t2
            }
        }
    }
}

/// A path in the design's 24-unit icon grid, scaled to any size.
struct SVGShape: Shape {
    let path: Path
    var viewBox: CGSize = CGSize(width: 24, height: 24)

    func path(in rect: CGRect) -> Path {
        path.applying(
            CGAffineTransform(translationX: rect.minX, y: rect.minY)
                .scaledBy(x: rect.width / viewBox.width, y: rect.height / viewBox.height)
        )
    }
}
