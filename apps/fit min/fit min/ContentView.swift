import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var timers: [SetTimer]

    @State private var isAccountPresented = false
    @State private var configuratorPresentation: ConfiguratorPresentation?
    @State private var timerPresentation: TimerPresentation?
    @State private var activeTimer: SetTimer?
    @State private var activeSession: SetTimerSessionController?

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
                activeTimer: activeTimer,
                activeSession: activeSession,
                onOpen: { timer in
                    let session = session(for: timer, startsImmediately: false)
                    timerPresentation = TimerPresentation(timer: timer, session: session)
                },
                onPlaybackButton: { timer in
                    if activeTimer === timer, let activeSession {
                        activeSession.togglePlayPause()
                    } else {
                        let session = session(for: timer, startsImmediately: true)
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 90_000_000)
                            guard activeTimer === timer, activeSession === session else { return }
                            timerPresentation = TimerPresentation(timer: timer, session: session)
                        }
                    }
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
            } onDelete: {
                if let timer = presentation.timer {
                    deleteTimer(timer)
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .sheet(item: $timerPresentation) { presentation in
            SetTimerDetailSheet(
                timer: presentation.timer,
                session: presentation.session,
                onEdit: {
                    timerPresentation = nil
                    configuratorPresentation = ConfiguratorPresentation(timer: presentation.timer)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .bottomSheetPullToDismiss()
        }
        .task {
            TimerSoundService.shared.prewarm()
            DefaultSetTimerSeeder.seedIfNeeded(existingTimers: timers, modelContext: modelContext)
            updateSiriTimerIndex()
            handlePendingTimerStart()
        }
        .onChange(of: timers.map(\.updatedAt)) {
            updateSiriTimerIndex()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            handlePendingTimerStart()
        }
        .onReceive(NotificationCenter.default.publisher(for: FitMinPendingTimerStartStore.didRequestStartNotification)) { _ in
            handlePendingTimerStart()
        }
    }

    private func saveTimer(_ timer: SetTimer?, configuration: SetTimerConfiguration, customTitle: String) {
        if let timer {
            timer.apply(configuration: configuration, customTitle: customTitle)
            if activeTimer === timer {
                activeSession?.pause()
                activeTimer = nil
                activeSession = nil
            }
        } else {
            modelContext.insert(SetTimer(customTitle: customTitle, configuration: configuration))
        }
        try? modelContext.save()
    }

    private func deleteTimer(_ timer: SetTimer) {
        withAnimation {
            if activeTimer === timer {
                activeSession?.pause()
                activeTimer = nil
                activeSession = nil
            }
            modelContext.delete(timer)
            try? modelContext.save()
        }
    }

    private func session(for timer: SetTimer, startsImmediately: Bool) -> SetTimerSessionController {
        if activeTimer === timer, let activeSession {
            if startsImmediately {
                activeSession.start()
            }
            return activeSession
        }

        activeSession?.pause()
        let session = SetTimerSessionController(
            configuration: timer.configuration,
            segments: timer.schedule,
            startsImmediately: false
        )
        session.onComplete = {
            timer.markCompleted()
            try? modelContext.save()
        }
        activeTimer = timer
        activeSession = session
        if startsImmediately {
            session.start()
        }
        return session
    }

    private func handlePendingTimerStart() {
        guard let requestedName = FitMinPendingTimerStartStore.consumePendingStartName() else { return }
        guard let timer = timer(named: requestedName) else { return }
        let session = session(for: timer, startsImmediately: true)
        timerPresentation = TimerPresentation(timer: timer, session: session)
    }

    private func timer(named name: String) -> SetTimer? {
        let normalized = FitMinTimerNameNormalizer.normalize(name)
        guard !normalized.isEmpty else { return nil }
        return timers.first { timer in
            FitMinTimerNameNormalizer.normalize(timer.displayTitle) == normalized
        } ?? timers.first { timer in
            FitMinTimerNameNormalizer.normalize(timer.displayTitle).contains(normalized)
                || normalized.contains(FitMinTimerNameNormalizer.normalize(timer.displayTitle))
        } ?? timers.first { timer in
            let requestedWords = FitMinTimerNameNormalizer.words(in: normalized)
            let timerWords = FitMinTimerNameNormalizer.words(in: FitMinTimerNameNormalizer.normalize(timer.displayTitle))
            return !requestedWords.isEmpty && requestedWords.isSubset(of: timerWords)
        }
    }

    private func updateSiriTimerIndex() {
        FitMinTimerIndexStore.save(timers: sortedTimers)
    }
}

struct ConfiguratorPresentation: Identifiable {
    let id = UUID()
    let timer: SetTimer?
}

struct TimerPresentation: Identifiable {
    let id = UUID()
    let timer: SetTimer
    let session: SetTimerSessionController
}

struct SetTimerListView: View {
    let timers: [SetTimer]
    let activeTimer: SetTimer?
    let activeSession: SetTimerSessionController?
    var onOpen: (SetTimer) -> Void
    var onPlaybackButton: (SetTimer) -> Void
    var onEdit: (SetTimer) -> Void
    var onDelete: (SetTimer) -> Void
    @State private var titleTypeInitialY: CGFloat?

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
                                liveSession: liveSession(for: timer),
                                onOpen: { onOpen(timer) },
                                onPlaybackButton: { onPlaybackButton(timer) }
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
        .coordinateSpace(name: "setTimerListScroll")
        .themeBackground()
    }

    private var titleTypeMark: some View {
        Image("Title Type")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(DesignSystem.Colors.accent)
            .frame(
                maxWidth: MinSpacing.TitleType.maxWidth,
                maxHeight: MinSpacing.TitleType.maxHeight,
                alignment: .leading
            )
            .compositingGroup()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .named("setTimerListScroll")).minY
            } action: { newValue in
                if titleTypeInitialY == nil {
                    titleTypeInitialY = newValue
                }
            }
            .visualEffect { content, proxy in
                let scrollY = proxy.frame(in: .named("setTimerListScroll")).minY
                let initial = titleTypeInitialY ?? scrollY
                let drift = initial - scrollY
                let progress = min(max(drift / MinSpacing.TitleType.blurDistance, 0), 1)
                return content
                    .offset(y: drift)
                    .blur(radius: progress * MinSpacing.TitleType.maxBlurRadius)
                    .opacity(1.0 - progress * MinSpacing.TitleType.maxOpacityReduction)
            }
            .zIndex(-1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func liveSession(for timer: SetTimer) -> SetTimerSessionController? {
        activeTimer === timer ? activeSession : nil
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
    let liveSession: SetTimerSessionController?
    var onOpen: () -> Void
    var onPlaybackButton: () -> Void

    private let visualAssetSize: CGFloat = 72

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                SetTimerClockAssetView(timer: timer, liveSession: liveSession)
                    .frame(width: visualAssetSize, height: visualAssetSize)
                    .contentShape(Circle())

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(timer.displayTitle)
                        .font(DesignSystem.Typography.headlineLarge())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)

                    Text(metadataText)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onOpen()
            }

            Button(action: onPlaybackButton) {
                Image(systemName: liveSession?.isPlaying == true ? DesignSystem.Icon.pause : DesignSystem.Icon.play)
                    .font(.system(size: 28))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
            .buttonStyle(.plain)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .accessibilityLabel(liveSession?.isPlaying == true ? "Pause \(timer.displayTitle)" : "Start \(timer.displayTitle)")
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .contentShape(Rectangle())
    }

    private var metadataText: String {
        timer.blockStyleLabel
    }
}

struct SetTimerClockAssetView: View {
    let timer: SetTimer
    let liveSession: SetTimerSessionController?

    private var marks: [TimerSecondMark] {
        liveSession?.marks ?? TimerSecondMark.marks(for: timer.schedule)
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                guard !marks.isEmpty else { return }
                let side = min(size.width, size.height)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = max(0, side / 2 - 2)
                let total = Double(marks.count)
                let currentMarkID = liveSession?.currentMarkID
                let countdownProgress = liveSession?.readyCountdownWindProgress ?? 0

                func draw(_ mark: TimerSecondMark, color: Color, length: CGFloat, lineWidth: CGFloat) {
                    let progress = Double(mark.id) / total
                    let angle = CGFloat(-Double.pi / 2 + progress * Double.pi * 2)
                    let outer = CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )
                    let inner = CGPoint(
                        x: center.x + cos(angle) * max(0, radius - length),
                        y: center.y + sin(angle) * max(0, radius - length)
                    )
                    var path = Path()
                    path.move(to: inner)
                    path.addLine(to: outer)
                    context.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                }

                func anticlockwiseProgress(for mark: TimerSecondMark) -> Double {
                    guard mark.id != 0 else { return 0 }
                    return (total - Double(mark.id)) / total
                }

                for mark in marks where mark.id != 0 && mark.id != currentMarkID {
                    let isComplete = liveSession.map { mark.id < $0.elapsedSeconds } ?? false
                    draw(
                        mark,
                        color: isComplete ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.accent,
                        length: mark.segmentKind == .work ? 8 : 4,
                        lineWidth: mark.segmentKind == .work ? 1.4 : 1
                    )
                }

                if let zeroMark = marks.first {
                    draw(zeroMark, color: DesignSystem.Colors.headlineColor, length: 12, lineWidth: 2.2)
                }

                if let currentMarkID,
                   let currentMark = marks.first(where: { $0.id == currentMarkID }) {
                    draw(currentMark, color: DesignSystem.Colors.index, length: 12, lineWidth: 2.2)
                }

                if liveSession?.isReadyCountdownActive == true {
                    for mark in marks {
                        let distanceBehindWave = countdownProgress - anticlockwiseProgress(for: mark)
                        guard distanceBehindWave >= 0, distanceBehindWave <= 0.18 else { continue }
                        let intensity = 1 - distanceBehindWave / 0.18
                        draw(
                            mark,
                            color: DesignSystem.Colors.highlight.opacity(0.35 + 0.65 * intensity),
                            length: (mark.segmentKind == .work ? 8 : 4) + 6 * intensity,
                            lineWidth: 1.4 + 1.4 * intensity
                        )
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ContentView()
        .environment(ThemeManager.shared)
        .modelContainer(for: SetTimer.self, inMemory: true)
}
