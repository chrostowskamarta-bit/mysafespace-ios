import SwiftUI

// MySafeSpace mood characters — designed by Marta Chróstowska
// (Figma: "Moods new animated", Design System page, component set 70:550).
// Five distinct characters, one per mood level, drawn as SwiftUI paths in a 100 × 100 space
// so they scale crisply with Dynamic Type. Colours come from the mood colour tokens (Light + Dark).

/// One drawable part of a mood character, in Marta's 100 × 100 artboard coordinates.
nonisolated enum MoodPart: Sendable {
    case badBody, badLidRight, badLidLeft
    case lowBody, lowLid
    case okayEyeLeft, okayEyeRight
    case goodBody
    case greatBody
}

nonisolated struct MoodPartShape: Shape {
    let part: MoodPart

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        let origin = CGPoint(x: rect.midX - 50 * scale, y: rect.midY - 50 * scale)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * scale, y: origin.y + y * scale) }
        var path = Path()
        switch part {
        case .badBody:
            path.move(to: p(50.26, 25.5))
            path.addCurve(to: p(86.08, 39.39), control1: p(66.58, 25.5), control2: p(78.37, 30.66))
            path.addCurve(to: p(97.5, 74.5), control1: p(93.71, 48.02), control2: p(97.41, 60.2))
            path.addLine(to: p(2.5, 74.5))
            path.addCurve(to: p(14.17, 39.39), control1: p(2.59, 60.21), control2: p(6.42, 48.02))
            path.addCurve(to: p(50.26, 25.5), control1: p(22.02, 30.67), control2: p(33.93, 25.5))
            path.closeSubpath()
        case .badLidRight:
            path.move(to: p(85.14, 39.1))
            path.addLine(to: p(82.55, 57.68))
            path.addLine(to: p(54.24, 45.71))
            path.addLine(to: p(65.77, 30.91))
            path.closeSubpath()
        case .badLidLeft:
            path.move(to: p(16.85, 45.71))
            path.addLine(to: p(16.85, 57.68))
            path.addLine(to: p(45.16, 45.71))
            path.addLine(to: p(33.63, 30.91))
            path.closeSubpath()
        case .lowBody:
            path.move(to: p(37.71, 10.48))
            path.addCurve(to: p(62.29, 10.48), control1: p(44.26, 3.16), control2: p(55.74, 3.16))
            path.addLine(to: p(64.92, 13.42))
            path.addLine(to: p(65.08, 13.59))
            path.addLine(to: p(65.32, 13.58))
            path.addLine(to: p(69.25, 13.36))
            path.addCurve(to: p(86.64, 30.75), control1: p(79.07, 12.82), control2: p(87.18, 20.93))
            path.addLine(to: p(86.42, 34.68))
            path.addLine(to: p(86.41, 34.92))
            path.addLine(to: p(86.59, 35.08))
            path.addLine(to: p(89.52, 37.71))
            path.addCurve(to: p(89.52, 62.29), control1: p(96.84, 44.26), control2: p(96.84, 55.74))
            path.addLine(to: p(86.59, 64.92))
            path.addLine(to: p(86.41, 65.08))
            path.addLine(to: p(86.42, 65.32))
            path.addLine(to: p(86.64, 69.25))
            path.addCurve(to: p(69.25, 86.64), control1: p(87.18, 79.07), control2: p(79.07, 87.18))
            path.addLine(to: p(65.32, 86.42))
            path.addLine(to: p(65.08, 86.41))
            path.addLine(to: p(64.92, 86.59))
            path.addLine(to: p(62.29, 89.52))
            path.addCurve(to: p(37.71, 89.52), control1: p(55.74, 96.84), control2: p(44.26, 96.84))
            path.addLine(to: p(35.08, 86.59))
            path.addLine(to: p(34.92, 86.41))
            path.addLine(to: p(34.68, 86.42))
            path.addLine(to: p(30.75, 86.64))
            path.addCurve(to: p(13.36, 69.25), control1: p(20.93, 87.18), control2: p(12.82, 79.07))
            path.addLine(to: p(13.58, 65.32))
            path.addLine(to: p(13.59, 65.08))
            path.addLine(to: p(13.42, 64.92))
            path.addLine(to: p(10.48, 62.29))
            path.addCurve(to: p(10.48, 37.71), control1: p(3.16, 55.74), control2: p(3.16, 44.26))
            path.addLine(to: p(13.42, 35.08))
            path.addLine(to: p(13.59, 34.92))
            path.addLine(to: p(13.58, 34.68))
            path.addLine(to: p(13.36, 30.75))
            path.addCurve(to: p(30.75, 13.36), control1: p(12.82, 20.93), control2: p(20.93, 12.82))
            path.addLine(to: p(34.68, 13.58))
            path.addLine(to: p(34.92, 13.59))
            path.addLine(to: p(35.08, 13.42))
            path.closeSubpath()
        case .lowLid:
            path.move(to: p(64.12, 20))
            path.addLine(to: p(71, 46))
            path.addLine(to: p(27.46, 46))
            path.addLine(to: p(34.33, 20))
            path.closeSubpath()
        case .okayEyeLeft:
            path.move(to: p(15.41, 49.32))
            path.addCurve(to: p(30.08, 40.24), control1: p(15.41, 49.32), control2: p(21.98, 40.24))
            path.addCurve(to: p(44.76, 49.32), control1: p(38.18, 40.24), control2: p(44.76, 49.32))
            path.addCurve(to: p(30.08, 58.4), control1: p(44.76, 49.32), control2: p(38.19, 58.4))
            path.addCurve(to: p(15.41, 49.32), control1: p(21.97, 58.4), control2: p(15.41, 49.32))
            path.closeSubpath()
        case .okayEyeRight:
            path.move(to: p(55.37, 49.32))
            path.addCurve(to: p(70.04, 40.24), control1: p(55.37, 49.32), control2: p(61.94, 40.24))
            path.addCurve(to: p(84.72, 49.32), control1: p(78.14, 40.24), control2: p(84.72, 49.32))
            path.addCurve(to: p(70.04, 58.4), control1: p(84.72, 49.32), control2: p(78.15, 58.4))
            path.addCurve(to: p(55.37, 49.32), control1: p(61.93, 58.4), control2: p(55.37, 49.32))
            path.closeSubpath()
        case .goodBody:
            path.move(to: p(58.52, 28.46))
            path.addLine(to: p(58.71, 28.98))
            path.addLine(to: p(59.21, 28.74))
            path.addLine(to: p(82.18, 17.82))
            path.addLine(to: p(71.26, 40.79))
            path.addLine(to: p(71.02, 41.29))
            path.addLine(to: p(71.54, 41.48))
            path.addLine(to: p(95.51, 50))
            path.addLine(to: p(71.54, 58.52))
            path.addLine(to: p(71.02, 58.71))
            path.addLine(to: p(71.26, 59.21))
            path.addLine(to: p(82.18, 82.18))
            path.addLine(to: p(59.21, 71.26))
            path.addLine(to: p(58.71, 71.02))
            path.addLine(to: p(58.52, 71.54))
            path.addLine(to: p(50, 95.51))
            path.addLine(to: p(41.48, 71.54))
            path.addLine(to: p(41.29, 71.02))
            path.addLine(to: p(40.79, 71.26))
            path.addLine(to: p(17.82, 82.18))
            path.addLine(to: p(28.74, 59.21))
            path.addLine(to: p(28.98, 58.71))
            path.addLine(to: p(28.46, 58.52))
            path.addLine(to: p(4.49, 50))
            path.addLine(to: p(28.46, 41.48))
            path.addLine(to: p(28.98, 41.29))
            path.addLine(to: p(28.74, 40.79))
            path.addLine(to: p(17.82, 17.82))
            path.addLine(to: p(40.79, 28.74))
            path.addLine(to: p(41.29, 28.98))
            path.addLine(to: p(41.48, 28.46))
            path.addLine(to: p(50, 4.49))
            path.closeSubpath()
        case .greatBody:
            path.move(to: p(83.07, 7.5))
            path.addCurve(to: p(86.2, 8.38), control1: p(84.33, 7.5), control2: p(85.36, 7.81))
            path.addCurve(to: p(88.24, 10.91), control1: p(87.04, 8.95), control2: p(87.72, 9.79))
            path.addCurve(to: p(89.44, 20.41), control1: p(89.29, 13.15), control2: p(89.66, 16.41))
            path.addCurve(to: p(81.91, 49.82), control1: p(88.98, 28.4), control2: p(86.14, 39.09))
            path.addCurve(to: p(66.19, 79.27), control1: p(77.69, 60.54), control2: p(72.1, 71.25))
            path.addCurve(to: p(57.25, 88.91), control1: p(63.24, 83.28), control2: p(60.21, 86.6))
            path.addCurve(to: p(48.8, 92.5), control1: p(54.29, 91.23), control2: p(51.43, 92.5))
            path.addCurve(to: p(39.75, 88.91), control1: p(45.86, 92.5), control2: p(42.81, 91.22))
            path.addCurve(to: p(30.76, 79.27), control1: p(36.7, 86.59), control2: p(33.66, 83.28))
            path.addCurve(to: p(15.89, 49.83), control1: p(24.95, 71.26), control2: p(19.72, 60.55))
            path.addCurve(to: p(9.51, 20.43), control1: p(12.07, 39.11), control2: p(9.67, 28.42))
            path.addCurve(to: p(11.01, 10.92), control1: p(9.43, 16.43), control2: p(9.91, 13.16))
            path.addCurve(to: p(13.08, 8.38), control1: p(11.56, 9.8), control2: p(12.25, 8.95))
            path.addCurve(to: p(16.12, 7.5), control1: p(13.91, 7.81), control2: p(14.92, 7.5))
            path.addCurve(to: p(36.79, 20.15), control1: p(24.17, 7.5), control2: p(31.22, 13.05))
            path.addCurve(to: p(48.33, 41.41), control1: p(42.35, 27.23), control2: p(46.35, 35.74))
            path.addLine(to: p(48.78, 42.71))
            path.addLine(to: p(49.27, 41.42))
            path.addCurve(to: p(61.46, 20.16), control1: p(51.38, 35.75), control2: p(55.62, 27.24))
            path.addCurve(to: p(83.07, 7.5), control1: p(67.31, 13.06), control2: p(74.69, 7.5))
            path.closeSubpath()
        }
        return path
    }
}

/// An ellipse or circle placed in the 100 × 100 artboard (eyes, pupils).
nonisolated struct MoodOval: Shape {
    let cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat
    init(cx: CGFloat, cy: CGFloat, r: CGFloat) { self.cx = cx; self.cy = cy; rx = r; ry = r }
    init(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) { self.cx = cx; self.cy = cy; self.rx = rx; self.ry = ry }

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 100
        let ox = rect.midX - 50 * s, oy = rect.midY - 50 * s
        return Path(ellipseIn: CGRect(x: ox + (cx - rx) * s, y: oy + (cy - ry) * s, width: rx * 2 * s, height: ry * 2 * s))
    }
}

/// A (rounded) rectangle placed in the 100 × 100 artboard.
nonisolated struct MoodRect: Shape {
    let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 100
        let ox = rect.midX - 50 * s, oy = rect.midY - 50 * s
        return Path(roundedRect: CGRect(x: ox + x * s, y: oy + y * s, width: w * s, height: h * s), cornerRadius: radius * s)
    }
}
