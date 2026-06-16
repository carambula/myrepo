import SwiftData
import SwiftUI

struct SetTimerDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let timer: SetTimer
    let session: SetTimerSessionController
    var onEdit: () -> Void
    @AppStorage("fitMin.timerSoundsEnabled") private var timerSoundsEnabled = true

    init(timer: SetTimer, session: SetTimerSessionController, onEdit: @escaping () -> Void) {
        self.timer = timer
        self.session = session
        self.onEdit = onEdit
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                SetTimerClockView(session: session)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(timer.displayTitle)
                        .font(DesignSystem.Typography.headlineLarge())
                        .foregroundStyle(DesignSystem.Colors.headlineColor)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(timer.blockStyleLabel)
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(detailMetadata)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

                SetTimerTransportControls(
                    isPlaying: session.isPlaying,
                    isSoundEnabled: timerSoundsEnabled,
                    canSkipBackward: session.currentSegmentIndex > 0 || session.elapsedSeconds > 0,
                    canSkipForward: session.currentSegmentIndex < session.segments.count - 1,
                    onToggleSound: toggleTimerSounds,
                    onBack: session.skipBackward,
                    onPlayPause: session.togglePlayPause,
                    onForward: session.skipForward,
                    onAdd: session.addRepAndRest
                )
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            }
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, MinSpacing.bottomSafeArea)
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: onEdit) {
                Image(systemName: DesignSystem.Icon.edit)
            }
            .buttonStyle(CircularGlassIconButtonStyle(size: MinSpacing.TopControls.buttonSize, foregroundColor: DesignSystem.Colors.accent))
            .accessibilityLabel("Edit timer")
            .padding(.trailing, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .themeBackground()
        .onAppear {
            session.onComplete = {
                timer.markCompleted()
                try? modelContext.save()
            }
        }
    }

    private var detailMetadata: String {
        "\(SetTimerTitleFormatter.clockDuration(session.totalSeconds)) total workout   Set completed \(timer.completedCount) times"
    }

    private func toggleTimerSounds() {
        timerSoundsEnabled.toggle()
        session.refreshSoundPlayback()
    }
}

struct SetTimerClockView: View {
    let session: SetTimerSessionController
    @AppStorage("fitMin.clockDisplayMode") private var clockDisplayModeRawValue = ClockDisplayMode.repsOnly.rawValue
    @AppStorage("fitMin.bouncesFinalIntervalTicks") private var bouncesFinalIntervalTicks = false
    @State private var finalIntervalTickScale = false
    @State private var readyCountdownScale = false

    private var clockDisplayMode: ClockDisplayMode {
        ClockDisplayMode(rawValue: clockDisplayModeRawValue) ?? .repsOnly
    }

    private var shouldEmphasizeFinalIntervalTick: Bool {
        clockDisplayMode == .intervalTimeOverReps && session.isInFinalIntervalCueWindow
    }

    private var countdownNumber: Int? {
        session.readyCountdownRemaining
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                let marks = session.marks
                guard !marks.isEmpty else { return }

                let side = min(size.width, size.height)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = max(0, side / 2 - DesignSystem.Spacing.screenHorizontalPadding)
                let total = Double(marks.count)
                let currentMarkID = session.currentMarkID
                let countdownProgress = session.readyCountdownWindProgress

                func draw(_ mark: TimerSecondMark, color: Color, length: CGFloat, lineWidth: CGFloat) {
                    let progress = Double(mark.id) / total
                    let angle = CGFloat(-Double.pi / 2 + progress * Double.pi * 2)
                    let outer = CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )
                    let innerRadius = max(0, radius - length)
                    let inner = CGPoint(
                        x: center.x + cos(angle) * innerRadius,
                        y: center.y + sin(angle) * innerRadius
                    )
                    var path = Path()
                    path.move(to: inner)
                    path.addLine(to: outer)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }

                func anticlockwiseProgress(for mark: TimerSecondMark) -> Double {
                    guard mark.id != 0 else { return 0 }
                    return (total - Double(mark.id)) / total
                }

                for mark in marks where mark.id != 0 && mark.id != currentMarkID {
                    let isComplete = mark.id < session.elapsedSeconds
                    let length: CGFloat = mark.segmentKind == .work ? 16 : 8
                    draw(
                        mark,
                        color: isComplete ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.accent,
                        length: length,
                        lineWidth: 1.5
                    )
                }

                if let zeroMark = marks.first {
                    draw(zeroMark, color: DesignSystem.Colors.headlineColor, length: 24, lineWidth: 3.0)
                }

                if let currentMarkID,
                   let currentMark = marks.first(where: { $0.id == currentMarkID }) {
                    let baseLength: CGFloat = currentMark.segmentKind == .work ? 16 : 8
                    draw(currentMark, color: DesignSystem.Colors.index, length: baseLength + 8, lineWidth: 3.2)
                }

                if session.isReadyCountdownActive {
                    for mark in marks {
                        let distanceBehindWave = countdownProgress - anticlockwiseProgress(for: mark)
                        guard distanceBehindWave >= 0, distanceBehindWave <= 0.18 else { continue }
                        let intensity = 1 - distanceBehindWave / 0.18
                        let baseLength: CGFloat = mark.segmentKind == .work ? 16 : 8
                        draw(
                            mark,
                            color: DesignSystem.Colors.highlight.opacity(0.35 + 0.65 * intensity),
                            length: baseLength + 10 * intensity,
                            lineWidth: 1.8 + 2.0 * intensity
                        )
                    }
                }
            }

            Button {
                session.toggleCenterMode()
            } label: {
                VStack(spacing: clockDisplayMode == .intervalTimeOverReps ? DesignSystem.Spacing.xs : DesignSystem.Spacing.xs) {
                    if let countdownNumber {
                        Text("\(countdownNumber)")
                            .font(DesignSystem.Typography.displayLarge())
                            .monospacedDigit()
                            .foregroundStyle(DesignSystem.Colors.headlineColor)
                            .scaleEffect(readyCountdownScale ? 1.16 : 1.0)
                            .contentTransition(.numericText())
                    } else {
                        if clockDisplayMode == .intervalTimeOverReps {
                            Text(SetTimerTitleFormatter.clockDuration(session.currentIntervalDisplaySeconds))
                                .font(DesignSystem.Typography.headlineLarge())
                                .monospacedDigit()
                                .foregroundStyle(shouldEmphasizeFinalIntervalTick ? DesignSystem.Colors.index : DesignSystem.Colors.headlineColor)
                                .scaleEffect(finalIntervalTickScale ? 1.12 : 1.0)
                                .contentTransition(.numericText())
                        }

                        Text("\(session.centerNumber)")
                            .font(DesignSystem.Typography.displayLarge())
                            .monospacedDigit()
                            .foregroundStyle(DesignSystem.Colors.headlineColor)
                            .contentTransition(.numericText())
                        Text(session.centerLabel)
                            .font(DesignSystem.Typography.caption())
                            .textCase(.uppercase)
                            .tracking(1.4)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                .frame(minWidth: 120, minHeight: 120)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(session.centerNumber) reps \(session.centerLabel)")
        }
        .onChange(of: session.elapsedSeconds) {
            pulseFinalIntervalTickIfNeeded()
        }
        .onChange(of: bouncesFinalIntervalTicks) {
            if !bouncesFinalIntervalTicks {
                finalIntervalTickScale = false
            }
        }
        .onChange(of: session.readyCountdownRemaining) {
            pulseReadyCountdown()
        }
    }

    private func pulseFinalIntervalTickIfNeeded() {
        guard shouldEmphasizeFinalIntervalTick, bouncesFinalIntervalTicks else {
            finalIntervalTickScale = false
            return
        }

        withAnimation(.spring(response: 0.16, dampingFraction: 0.48, blendDuration: 0)) {
            finalIntervalTickScale = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            withAnimation(.spring(response: 0.18, dampingFraction: 0.72, blendDuration: 0)) {
                finalIntervalTickScale = false
            }
        }
    }

    private func pulseReadyCountdown() {
        guard session.readyCountdownRemaining != nil else {
            readyCountdownScale = false
            return
        }

        withAnimation(.spring(response: 0.16, dampingFraction: 0.52, blendDuration: 0)) {
            readyCountdownScale = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.spring(response: 0.2, dampingFraction: 0.78, blendDuration: 0)) {
                readyCountdownScale = false
            }
        }
    }
}

struct SetTimerTransportControls: View {
    let isPlaying: Bool
    let isSoundEnabled: Bool
    let canSkipBackward: Bool
    let canSkipForward: Bool
    var onToggleSound: () -> Void
    var onBack: () -> Void
    var onPlayPause: () -> Void
    var onForward: () -> Void
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xl) {
            controlButton(
                systemName: isSoundEnabled ? DesignSystem.Icon.sound : DesignSystem.Icon.soundOff,
                label: isSoundEnabled ? "Turn sounds off" : "Turn sounds on",
                foregroundColor: isSoundEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary,
                action: onToggleSound
            )
            controlButton(systemName: DesignSystem.Icon.back, label: "Previous interval", isEnabled: canSkipBackward, action: onBack)

            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? DesignSystem.Icon.pause : DesignSystem.Icon.play)
                    .font(.system(size: DesignSystem.Controls.prominentButtonSize))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            controlButton(systemName: DesignSystem.Icon.forward, label: "Next interval", isEnabled: canSkipForward, action: onForward)
            controlButton(systemName: DesignSystem.Icon.add, label: "Add rep and rest", action: onAdd)
        }
        .frame(maxWidth: .infinity)
    }

    private func controlButton(
        systemName: String,
        label: String,
        isEnabled: Bool = true,
        foregroundColor: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isEnabled ? (foregroundColor ?? DesignSystem.Colors.textPrimary) : DesignSystem.Colors.textTertiary)
                .frame(width: 36, height: 56)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}

#Preview {
    let timer = SetTimer(configuration: SetTimerConfiguration())
    SetTimerDetailSheet(
        timer: timer,
        session: SetTimerSessionController(configuration: timer.configuration, segments: timer.schedule, startsImmediately: false),
        onEdit: {}
    )
        .environment(ThemeManager.shared)
        .modelContainer(for: SetTimer.self, inMemory: true)
}
