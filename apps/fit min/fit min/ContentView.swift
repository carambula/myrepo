import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var timers: [SetTimer]

    @State private var isAccountPresented = false
    @State private var configuratorPresentation: ConfiguratorPresentation?
    @State private var timerPresentation: TimerPresentation?

    private var sortedTimers: [SetTimer] {
        timers.sorted { lhs, rhs in
            let lhsDate = lhs.lastUsedAt ?? lhs.updatedAt
            let rhsDate = rhs.lastUsedAt ?? rhs.updatedAt
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            SetTimerListView(
                timers: sortedTimers,
                onOpen: { timer in
                    timerPresentation = TimerPresentation(timer: timer, startsImmediately: false)
                },
                onPlay: { timer in
                    timer.markUsed()
                    try? modelContext.save()
                    timerPresentation = TimerPresentation(timer: timer, startsImmediately: true)
                },
                onEdit: { timer in
                    configuratorPresentation = ConfiguratorPresentation(timer: timer)
                },
                onDelete: deleteTimer
            )
            .overlay(alignment: .bottomTrailing) {
                Button {
                    configuratorPresentation = ConfiguratorPresentation(timer: nil)
                } label: {
                    Image(systemName: DesignSystem.Icon.add)
                }
                .buttonStyle(CircularGlassIconButtonStyle(size: MinSpacing.TopControls.buttonSize, foregroundColor: DesignSystem.Colors.accent))
                .accessibilityLabel("Add timer")
                .padding(.trailing, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                HStack(spacing: MinSpacing.TopControls.horizontalPadding) {
                    Spacer()
                    Button {
                        isAccountPresented = true
                    } label: {
                        Image(systemName: DesignSystem.Icon.account)
                    }
                    .buttonStyle(CircularGlassIconButtonStyle())
                    .accessibilityLabel("Account and settings")
                }
                .padding(.horizontal, MinSpacing.lg)
                .padding(.top, MinSpacing.TopControls.verticalPadding)
                .padding(.bottom, MinSpacing.TopControls.verticalPadding)
            }
            .themeBackground()
        }
        .sheet(isPresented: $isAccountPresented) {
            AccountSheetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $configuratorPresentation) { presentation in
            SetTimerConfiguratorSheet(timer: presentation.timer) { configuration, customTitle in
                saveTimer(presentation.timer, configuration: configuration, customTitle: customTitle)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .sheet(item: $timerPresentation) { presentation in
            SetTimerDetailSheet(
                timer: presentation.timer,
                startsImmediately: presentation.startsImmediately,
                onEdit: {
                    timerPresentation = nil
                    configuratorPresentation = ConfiguratorPresentation(timer: presentation.timer)
                },
                onDelete: {
                    deleteTimer(presentation.timer)
                    timerPresentation = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .bottomSheetPullToDismiss()
        }
    }

    private func saveTimer(_ timer: SetTimer?, configuration: SetTimerConfiguration, customTitle: String) {
        if let timer {
            timer.apply(configuration: configuration, customTitle: customTitle)
        } else {
            modelContext.insert(SetTimer(customTitle: customTitle, configuration: configuration))
        }
        try? modelContext.save()
    }

    private func deleteTimer(_ timer: SetTimer) {
        withAnimation {
            modelContext.delete(timer)
            try? modelContext.save()
        }
    }
}

struct ConfiguratorPresentation: Identifiable {
    let id = UUID()
    let timer: SetTimer?
}

struct TimerPresentation: Identifiable {
    let id = UUID()
    let timer: SetTimer
    let startsImmediately: Bool
}

struct SetTimerListView: View {
    let timers: [SetTimer]
    var onOpen: (SetTimer) -> Void
    var onPlay: (SetTimer) -> Void
    var onEdit: (SetTimer) -> Void
    var onDelete: (SetTimer) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                titleTypeMark
                    .padding(.horizontal, MinSpacing.TitleType.horizontalPadding)
                    .offset(y: MinSpacing.TitleType.markOffsetY)

                if timers.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(timers) { timer in
                            SetTimerRow(
                                timer: timer,
                                onOpen: { onOpen(timer) },
                                onPlay: { onPlay(timer) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    onDelete(timer)
                                } label: {
                                    Label("Delete", systemImage: DesignSystem.Icon.delete)
                                }

                                Button {
                                    onEdit(timer)
                                } label: {
                                    Label("Edit", systemImage: DesignSystem.Icon.edit)
                                }
                                .tint(DesignSystem.Colors.accent)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.top, MinSpacing.TitleType.contentTopSpacing)
                    .padding(.bottom, MinSpacing.bottomSafeArea)
                }
            }
            .padding(.top, MinSpacing.TitleType.scrollTopPadding)
        }
        .scrollClipDisabled()
        .themeBackground()
    }

    private var titleTypeMark: some View {
        Text("fit min")
            .font(.system(size: 38, weight: .black, design: .rounded))
            .foregroundStyle(DesignSystem.Colors.headlineColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Build your first set timer.")
                .font(DesignSystem.Typography.headlineLarge())
                .foregroundStyle(DesignSystem.Colors.headlineColor)
            Text("Start with reps, work intervals, and rests. The add button creates fixed, ladder, pyramid, or wave sets.")
                .font(DesignSystem.Typography.bodyMedium())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        .padding(.top, DesignSystem.Spacing.xxl)
    }
}

struct SetTimerRow: View {
    let timer: SetTimer
    var onOpen: () -> Void
    var onPlay: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(timer.displayTitle)
                        .font(DesignSystem.Typography.displayMedium())
                        .foregroundStyle(DesignSystem.Colors.headlineColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text(metadataText)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer(minLength: DesignSystem.Spacing.md)

                Button(action: onPlay) {
                    Image(systemName: DesignSystem.Icon.playSmall)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ThemeManager.shared.currentTheme.onAccent)
                        .frame(width: 52, height: 52)
                        .background(DesignSystem.Colors.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start \(timer.displayTitle)")
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(DesignSystem.Colors.divider, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }

    private var metadataText: String {
        let total = SetTimerTitleFormatter.clockDuration(timer.totalDurationSeconds)
        return "\(total) total workout   Set completed \(timer.completedCount) times"
    }
}

#Preview {
    ContentView()
        .environment(ThemeManager.shared)
        .modelContainer(for: SetTimer.self, inMemory: true)
}
