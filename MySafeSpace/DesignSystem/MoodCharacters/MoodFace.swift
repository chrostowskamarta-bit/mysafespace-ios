import SwiftUI

/// A mood character (Marta's design, Figma "Moods new animated"). One character per mood level.
/// Announces its meaning to VoiceOver ("Mood: Low"). Gentle idle motion — blink, turn, bounce,
/// pulse — is switched off with Reduce Motion and for tiny faces (calendar cells).
struct MoodFace: View {
    var progress: Double
    var size: CGFloat = 56
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(progress: Double, size: CGFloat = 56) {
        self.progress = progress
        self.size = size
    }

    init(level: MoodLevel, size: CGFloat = 56) {
        self.init(progress: level.progress, size: size)
    }

    private var level: MoodLevel { MoodLevel(progress: progress) }
    private var animated: Bool { !reduceMotion && size >= 36 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animated)) { context in
            character(time: animated ? context.date.timeIntervalSinceReferenceDate : 0)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(Text("Mood: \(level.label)"))
    }

    // MARK: Characters

    @ViewBuilder
    private func character(time t: TimeInterval) -> some View {
        let fill = level.color
        switch level {
        case .veryLow: // Bad — half dome, droopy lids, slow blink
            ZStack {
                outlined(.badBody, fill)
                ZStack {
                    MoodOval(cx: 68, cy: 52, r: 13).fill(.white)
                    MoodOval(cx: 67.5, cy: 53.5, r: 5.5).fill(Color.moodInk)
                    MoodPartShape(part: .badLidRight).fill(fill)
                }
                .scaleEffect(x: 1, y: blink(t, every: 2.6), anchor: UnitPoint(x: 0.68, y: 0.52))
                ZStack {
                    MoodOval(cx: 31.5, cy: 52, rx: 13.5, ry: 13).fill(.white)
                    MoodOval(cx: 32.5, cy: 53.5, r: 5.5).fill(Color.moodInk)
                    MoodPartShape(part: .badLidLeft).fill(fill)
                }
                .scaleEffect(x: 1, y: blink(t - 0.12, every: 2.6), anchor: UnitPoint(x: 0.315, y: 0.52))
            }
        case .low: // Low — scalloped flower that slowly turns, one big eye under a heavy lid
            ZStack {
                outlined(.lowBody, fill)
                    .rotationEffect(.degrees(t.truncatingRemainder(dividingBy: 14) / 14 * 360))
                ZStack {
                    MoodOval(cx: 50, cy: 50, r: 19).fill(.white)
                    MoodOval(cx: 50.5, cy: 50.5, r: 8.5).fill(Color.moodInk)
                    MoodPartShape(part: .lowLid).fill(fill)
                }
                .clipShape(MoodOval(cx: 50, cy: 50, r: 19))
            }
        case .okay: // Okay — rounded square, almond eyes, blink
            ZStack {
                MoodRect(x: 6.5, y: 6.5, w: 86, h: 86, radius: 20.5).fill(fill)
                MoodRect(x: 6.5, y: 6.5, w: 86, h: 86, radius: 20.5).stroke(Color.moodInk, lineWidth: line)
                ZStack {
                    MoodPartShape(part: .okayEyeLeft).fill(.white)
                    MoodOval(cx: 30, cy: 49, r: 6).fill(Color.moodInk)
                }
                .scaleEffect(x: 1, y: blink(t), anchor: UnitPoint(x: 0.3, y: 0.49))
                ZStack {
                    MoodPartShape(part: .okayEyeRight).fill(.white)
                    MoodOval(cx: 70, cy: 49, r: 6).fill(Color.moodInk)
                }
                .scaleEffect(x: 1, y: blink(t - 0.12), anchor: UnitPoint(x: 0.7, y: 0.49))
            }
        case .good: // Good — eight-point star, bounce & wiggle
            let phase = sin(t / 2.6 * 2 * .pi)
            ZStack {
                outlined(.goodBody, fill)
                MoodOval(cx: 43, cy: 47.5, rx: 7, ry: 9.5).fill(.white)
                MoodOval(cx: 38.5, cy: 47.5, rx: 2.5, ry: 5.5).fill(Color.moodInk)
                MoodOval(cx: 58, cy: 47.5, rx: 7, ry: 9.5).fill(.white)
                MoodOval(cx: 53.5, cy: 47.5, rx: 2.5, ry: 5.5).fill(Color.moodInk)
            }
            .rotationEffect(.degrees(phase * 4), anchor: .bottom)
            .offset(y: -size * 0.04 * max(0, phase))
        case .great: // Great — heart, gentle pulse & sway, smiling squint
            let phase = (1 - cos(t / 3.2 * 2 * .pi)) / 2
            ZStack {
                outlined(.greatBody, fill)
                ZStack {
                    MoodOval(cx: 37.5, cy: 55.5, r: 9.5).fill(.white)
                    MoodOval(cx: 58.5, cy: 55.5, r: 9.5).fill(.white)
                    MoodOval(cx: 34, cy: 53, r: 4).fill(Color.moodInk)
                    MoodOval(cx: 54, cy: 53, r: 4).fill(Color.moodInk)
                    MoodRect(x: 26, y: 55, w: 47, h: 10, radius: 0).fill(fill)
                }
                .scaleEffect(x: 1, y: blink(t, every: 2.6), anchor: UnitPoint(x: 0.48, y: 0.555))
            }
            .scaleEffect(1 + 0.05 * phase, anchor: UnitPoint(x: 0.5, y: 0.9))
            .rotationEffect(.degrees(-3 * phase), anchor: UnitPoint(x: 0.5, y: 0.9))
        }
    }

    private var line: CGFloat { max(1, size / 100) }

    private func outlined(_ part: MoodPart, _ fill: Color) -> some View {
        ZStack {
            MoodPartShape(part: part).fill(fill)
            MoodPartShape(part: part).stroke(Color.moodInk, style: StrokeStyle(lineWidth: line, lineJoin: .round))
        }
    }

    /// Eye height factor: open most of the time, a quick blink every `period` seconds
    /// (4.8 s by default; Bad and Great blink more often, every 2.6 s).
    private func blink(_ t: TimeInterval, every period: TimeInterval = 4.8) -> CGFloat {
        guard animated else { return 1 }
        let f = (t.truncatingRemainder(dividingBy: period) + period).truncatingRemainder(dividingBy: period) / period
        switch f {
        case 0.92..<0.95: return 1 - 0.9 * CGFloat((f - 0.92) / 0.03)
        case 0.95..<0.98: return 0.1 + 0.9 * CGFloat((f - 0.95) / 0.03)
        default: return 1
        }
    }
}

/// Face slider (the only required check-in step). The character changes as you drag.
struct MoodPicker: View {
    @Binding var level: MoodLevel
    @State private var progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var faceSize: CGFloat = 150

    init(level: Binding<MoodLevel>) {
        _level = level
        _progress = State(initialValue: level.wrappedValue.progress)
    }

    var body: some View {
        VStack(spacing: Spacing.m) {
            MoodFace(progress: progress, size: min(faceSize, 220))
                .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: progress)
                .accessibilityHidden(true)
            Text(level.label)
                .font(.screenTitle)
                .foregroundStyle(Color.ink)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: level)
                .accessibilityHidden(true)
            // Solid track (no gradient), brand colour.
            Slider(value: $progress, in: 0...1, step: 0.25) {
                Text("Mood")
            } minimumValueLabel: {
                Image(systemName: "cloud.rain").accessibilityHidden(true)
            } maximumValueLabel: {
                Image(systemName: "sun.max").accessibilityHidden(true)
            }
            .tint(Color.brandPrimary.opacity(0.5)) // Marta's Figma: slider track at 50%
            .foregroundStyle(Color.inkSecondary)
            .accessibilityLabel(Text("How are you today?"))
            .accessibilityValue(Text(level.label))
        }
        .onChange(of: progress) { _, newValue in
            let newLevel = MoodLevel(progress: newValue)
            if newLevel != level { level = newLevel }
        }
        .onChange(of: level) { _, newLevel in
            if MoodLevel(progress: progress) != newLevel { progress = newLevel.progress }
        }
        .sensoryFeedback(.selection, trigger: level)
    }
}

/// Five tappable faces (Home card, entry editor). Large targets for low-effort days.
struct MoodRow: View {
    var selection: MoodLevel?
    var faceSize: CGFloat = 48
    let onSelect: (MoodLevel) -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(MoodLevel.allCases) { level in
                Button {
                    onSelect(level)
                } label: {
                    VStack(spacing: 4) {
                        MoodFace(level: level, size: faceSize)
                            .accessibilityHidden(true)
                            .opacity(selection == nil || selection == level ? 1 : 0.5)
                            .scaleEffect(selection == level ? 1.08 : 1)
                        Text(level.label)
                            .font(.caption2.weight(selection == level ? .bold : .regular))
                            .foregroundStyle(Color.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: minTapTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Mood: \(level.label)"))
                .accessibilityAddTraits(selection == level ? .isSelected : [])
            }
        }
    }
}

#Preview("Mood faces") {
    @Previewable @State var level = MoodLevel.okay
    ScrollView {
        VStack(spacing: 32) {
            HStack {
                ForEach(MoodLevel.allCases) { MoodFace(level: $0, size: 64) }
            }
            MoodPicker(level: $level)
            MoodRow(selection: level) { level = $0 }
        }
        .padding()
    }
    .screenBackground()
}
