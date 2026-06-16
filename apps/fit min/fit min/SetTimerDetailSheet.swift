import SwiftData
import SwiftUI

struct SetTimerDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let timer: SetTimer
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var session: SetTimerSessionController

    init(timer: SetTimer, startsImmediately: Bool, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.timer = timer
        self.onEdit = onEdit
        self.onDelete = onDelete
        _session = State(initialValue: SetTimerSessionController(configuration: timer.configuration, startsImmediately: startsImmediately))
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

                    Text(detailMetadata)
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

                SetTimerTransportControls(
                    isPlaying: session.isPlaying,
                    canSkipBackward: session.currentSegmentIndex > 0 || session.elapsedSeconds > 0,
                    canSkipForward: session.currentSegmentIndex < session.segments.count - 1,
                    onEdit: onEdit,
                    onBack: session.skipBackward,
                    onPlayPause: session.togglePlayPause,
                    onForward: session.skipForward,
                    onAdd: session.addRepAndRest
                )
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete set timer", systemImage: DesignSystem.Icon.delete)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .destructive))
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.top, DesignSystem.Spacing.xl)
            }
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, MinSpacing.bottomSafeArea)
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
}

struct SetTimerClockView: View {
    let session: SetTimerSessionController

    var body: some View {
        ZStack {
            Canvas { context, size in
                let marks = session.marks
                guard !marks.isEmpty else { return }

                let side = min(size.width, size.height)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = max(0, side / 2 - DesignSystem.Spacing.screenHorizontalPadding)
                let total = Double(marks.count)

                for mark in marks {
                    let progress = Double(mark.id) / total
                    let angle = -Double.pi / 2 + progress * Double.pi * 2
                    let isCurrent = mark.id == session.currentMarkID
                    let isComplete = mark.id < session.elapsedSeconds
                    let baseLength: CGFloat = mark.segmentKind == .work ? 16 : 8
                    let length = isCurrent ? baseLength + 8 : baseLength
                    let lineWidth: CGFloat = isCurrent ? 3.2 : 1.5
                    let color: Color = {
                        if isCurrent { return DesignSystem.Colors.highlight }
                        if isComplete { return DesignSystem.Colors.textTertiary }
                        return DesignSystem.Colors.accent
                    }()

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
            }

            Button {
                session.toggleCenterMode()
            } label: {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("\(session.centerNumber)")
                        .font(DesignSystem.Typography.displayLarge())
                        .foregroundStyle(DesignSystem.Colors.headlineColor)
                        .contentTransition(.numericText())
                    Text(session.centerLabel)
                        .font(DesignSystem.Typography.caption())
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .frame(minWidth: 120, minHeight: 120)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(session.centerNumber) reps \(session.centerLabel)")
        }
    }
}

struct SetTimerTransportControls: View {
    let isPlaying: Bool
    let canSkipBackward: Bool
    let canSkipForward: Bool
    var onEdit: () -> Void
    var onBack: () -> Void
    var onPlayPause: () -> Void
    var onForward: () -> Void
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xl) {
            controlButton(systemName: DesignSystem.Icon.edit, label: "Edit", action: onEdit)
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

    private func controlButton(systemName: String, label: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isEnabled ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                .frame(width: 36, height: 56)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}

#Preview {
    let timer = SetTimer(configuration: SetTimerConfiguration())
    SetTimerDetailSheet(timer: timer, startsImmediately: false, onEdit: {}, onDelete: {})
        .environment(ThemeManager.shared)
        .modelContainer(for: SetTimer.self, inMemory: true)
}
