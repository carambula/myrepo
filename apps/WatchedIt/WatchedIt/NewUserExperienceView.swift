//
//  NewUserExperienceView.swift
//  WatchedIt
//
//  Full-screen new user experience: informational intro and optional settings pages.
//  Shown on app start when intro has not been seen or a setting is not yet configured.
//  iOS only.
//

import SwiftUI
import SwiftData

#if os(iOS)

// MARK: - Page Model

private enum OnboardingPage: Identifiable {
    case intro
    case streaming
    case podcast
    case lists
    
    var id: String {
        switch self {
        case .intro: return "intro"
        case .streaming: return "streaming"
        case .podcast: return "podcast"
        case .lists: return "lists"
        }
    }
    
    var iconName: String {
        switch self {
        case .intro: return "film.stack"
        case .streaming: return DesignSystem.Icon.streaming
        case .podcast: return DesignSystem.Icon.podcast
        case .lists: return DesignSystem.Icon.list
        }
    }
    
    var featureName: String {
        switch self {
        case .intro: return "WatchedIt"
        case .streaming: return "Streaming Services"
        case .podcast: return "Podcast App"
        case .lists: return "Lists"
        }
    }
}

// MARK: - New User Experience View

struct NewUserExperienceView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(OnboardingState.introSeenKey) private var introSeen = false
    @AppStorage(OnboardingState.streamingCompletedKey) private var streamingCompleted = false
    @AppStorage(OnboardingState.podcastCompletedKey) private var podcastCompleted = false
    @AppStorage(OnboardingState.listsCompletedKey) private var listsCompleted = false
    @AppStorage(StreamingPreferences.storageKey) private var preferredServicesData: Data = Data()
    @AppStorage(ListPreferences.storageKey) private var preferredListsData: Data = Data()
    @AppStorage(PodcastAppPreferences.storageKey) private var preferredPodcastAppName: String = ""
    
    @State private var currentPageIndex: Int = 0
    @State private var showConfigureSheet = false
    @State private var configureTarget: OnboardingPage?
    /// Frozen at first appearance so dot count stays N for the whole session.
    @State private var totalDotCount: Int = 0
    
    /// Keep index in bounds when pages change (e.g. after completing intro).
    private func clampedPageIndex() -> Int {
        let count = pages.count
        guard count > 0 else { return 0 }
        return min(max(0, currentPageIndex), count - 1)
    }
    
    private var pages: [OnboardingPage] {
        var p: [OnboardingPage] = []
        if !introSeen { p.append(.intro) }
        if !streamingCompleted { p.append(.streaming) }
        if !podcastCompleted { p.append(.podcast) }
        if !listsCompleted { p.append(.lists) }
        return p
    }
    
    private var streamingConfigured: Bool {
        !StreamingPreferences.decode(from: preferredServicesData).isEmpty
    }
    
    private var podcastConfigured: Bool {
        let name = (preferredPodcastAppName as String).trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return true }
        return (PodcastAppPreferences.preferredAppName() ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
    
    private var listsConfigured: Bool {
        ListPreferences.hasInitialized()
    }
    
    private var currentPage: OnboardingPage? {
        let idx = clampedPageIndex()
        guard idx < pages.count else { return nil }
        return pages[idx]
    }
    
    private var isLastPage: Bool {
        let count = pages.count
        guard count > 0 else { return true }
        return clampedPageIndex() == count - 1
    }
    
    private func isConfigured(for page: OnboardingPage) -> Bool {
        switch page {
        case .intro: return true
        case .streaming: return streamingConfigured
        case .podcast: return podcastConfigured
        case .lists: return listsConfigured
        }
    }
    
    private func ctaTitle(for page: OnboardingPage) -> String {
        switch page {
        case .intro: return "Next"
        case .streaming:
            return isConfigured(for: .streaming) ? "Next" : "Configure Streaming Services"
        case .podcast:
            return isConfigured(for: .podcast) ? "Next" : "Configure Podcast App"
        case .lists:
            return isConfigured(for: .lists) ? "Next" : "Configure Lists"
        }
    }
    
    private func primaryButtonTitle() -> String {
        guard let page = currentPage else { return "Done" }
        if isLastPage && isConfigured(for: page) {
            return "Done"
        }
        return ctaTitle(for: page)
    }

    private var isPrimaryCompletionAction: Bool {
        guard let page = currentPage else { return true }
        return isLastPage && isConfigured(for: page)
    }
    
    private func primaryButtonAction() {
        guard let page = currentPage else { return }
        if isLastPage && isConfigured(for: page) {
            markCompleted(for: page)
            return
        }
        switch page {
        case .intro:
            introSeen = true
            advanceOrDismiss()
        case .streaming:
            if isConfigured(for: .streaming) {
                streamingCompleted = true
                advanceOrDismiss()
            } else {
                configureTarget = .streaming
                showConfigureSheet = true
            }
        case .podcast:
            if isConfigured(for: .podcast) {
                podcastCompleted = true
                advanceOrDismiss()
            } else {
                configureTarget = .podcast
                showConfigureSheet = true
            }
        case .lists:
            if isConfigured(for: .lists) {
                listsCompleted = true
                advanceOrDismiss()
            } else {
                configureTarget = .lists
                showConfigureSheet = true
            }
        }
    }
    
    private func markCompleted(for page: OnboardingPage) {
        switch page {
        case .intro: introSeen = true
        case .streaming: streamingCompleted = true
        case .podcast: podcastCompleted = true
        case .lists: listsCompleted = true
        }
    }
    
    private func advanceOrDismiss() {
        // We just completed the current step, so the pages array may have shrunk.
        // The "next" page is always the first of the remaining list (index 0).
        let count = pages.count
        withAnimation(DesignSystem.Animation.standard) {
            currentPageIndex = count > 0 ? 0 : 0
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DesignSystem.Color.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top third: white space with icon + title at the 1/3 line, vertically aligned
                    ZStack(alignment: .bottom) {
                        Color.clear
                        if let page = currentPage {
                            HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: page.iconName)
                                    .font(.system(size: DesignSystem.IconSize.xl))
                                    .foregroundColor(DesignSystem.Color.accent)
                                Text(page.featureName)
                                    .font(DesignSystem.Typography.headlineMedium)
                                    .foregroundColor(DesignSystem.Color.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                            .padding(.bottom, DesignSystem.Spacing.lg)
                        }
                    }
                    .frame(height: geometry.size.height / 3)
                    
                    // Middle: headline / content
                    if let page = currentPage {
                        ScrollView {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                                headlineView(for: page)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DesignSystem.Spacing.lg)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    Spacer(minLength: 0)
                
                // Bottom: primary button
                Button(action: primaryButtonAction) {
                    if isPrimaryCompletionAction {
                        Image(systemName: DesignSystem.Icon.checkmark)
                            .font(.system(size: DesignSystem.IconSize.lg, weight: .semibold))
                            .foregroundColor(DesignSystem.Color.accent)
                            .padding(DesignSystem.Spacing.sm)
                            .background(Color.white.opacity(0.96))
                            .clipShape(Circle())
                    } else {
                        Text(primaryButtonTitle())
                            .font(DesignSystem.Typography.labelLarge)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(DesignSystem.Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.bottom, DesignSystem.Spacing.sm)
                .accessibilityLabel(isPrimaryCompletionAction ? "Done" : primaryButtonTitle())
                
                // Pager dots (non-interactive): N dots, current step black
                let dotCount = totalDotCount > 0 ? totalDotCount : pages.count
                let completedSteps = dotCount - pages.count
                let activeDotIndex = min(completedSteps + clampedPageIndex(), dotCount - 1)
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(0..<max(1, dotCount), id: \.self) { index in
                        Circle()
                            .fill(index == activeDotIndex ? DesignSystem.Color.textPrimary : DesignSystem.Color.textTertiary)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
        }
        .sheet(isPresented: $showConfigureSheet) {
            if let target = configureTarget {
                configureSheetContent(for: target)
                    .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: showConfigureSheet) { _, isShowing in
            if !isShowing {
                configureTarget = nil
            }
        }
        .onAppear {
            if totalDotCount == 0, !pages.isEmpty {
                totalDotCount = pages.count
            }
        }
    }
    
    @ViewBuilder
    private func headlineView(for page: OnboardingPage) -> some View {
        switch page {
        case .intro:
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Introducing WatchedIt")
                    .font(DesignSystem.Typography.headlineLarge)
                    .foregroundColor(DesignSystem.Color.textPrimary)
                Text("The guide to watching films along with your favorite movie podcasts and movie lists.")
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Color.textSecondary)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    bullet("Save movies you want to watch and/or pod")
                    bullet("Press play for trailers or to find the movie on your saved streamers")
                    bullet("Press the Mic icon to listen to the related pods or mark as listened")
                    bullet("Hit popcorn to mark as watched")
                    bullet("Mark movies as watched or podded")
                    bullet("Your activity can sync with Min Cloud, or stay on-device with optional iCloud backup")
                }
            }
        case .streaming:
            Text("Choose your preferred streaming services and their order. They’ll appear first when you look up where to watch a movie.")
                .font(DesignSystem.Typography.bodyLarge)
                .foregroundColor(DesignSystem.Color.textPrimary)
        case .podcast:
            Text("Pick which app opens when you tap podcast links or mark an episode as listened.")
                .font(DesignSystem.Typography.bodyLarge)
                .foregroundColor(DesignSystem.Color.textPrimary)
        case .lists:
            Text("Select which lists (e.g. AFI, Rotten Tomatoes) show in Inspiration and filters.")
                .font(DesignSystem.Typography.bodyLarge)
                .foregroundColor(DesignSystem.Color.textPrimary)
        }
    }
    
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Text("•")
                .font(DesignSystem.Typography.bodyLarge)
                .foregroundColor(DesignSystem.Color.accent)
            Text(text)
                .font(DesignSystem.Typography.bodyLarge)
                .foregroundColor(DesignSystem.Color.textPrimary)
        }
    }
    
    @ViewBuilder
    private func configureSheetContent(for page: OnboardingPage) -> some View {
        switch page {
        case .intro:
            EmptyView()
        case .streaming:
            NavigationView {
                StreamingServicesPreferencesView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showConfigureSheet = false
                            } label: {
                                Image(systemName: DesignSystem.Icon.checkmark)
                            }
                            .accessibilityLabel("Done")
                        }
                    }
            }
            .bottomSheetPullToDismiss()
        case .podcast:
            NavigationView {
                PodcastAppPreferencesView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showConfigureSheet = false
                            } label: {
                                Image(systemName: DesignSystem.Icon.checkmark)
                            }
                            .accessibilityLabel("Done")
                        }
                    }
            }
            .bottomSheetPullToDismiss()
        case .lists:
            NavigationView {
                ListPreferencesView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showConfigureSheet = false
                            } label: {
                                Image(systemName: DesignSystem.Icon.checkmark)
                            }
                            .accessibilityLabel("Done")
                        }
                    }
            }
            .bottomSheetPullToDismiss()
        }
    }
}

// MARK: - Container that shows onboarding overlay when needed (use in app root on iOS)

struct NewUserExperienceOverlayContainer<Content: View>: View {
    @AppStorage(OnboardingState.introSeenKey) private var introSeen = false
    @AppStorage(OnboardingState.streamingCompletedKey) private var streamingCompleted = false
    @AppStorage(OnboardingState.podcastCompletedKey) private var podcastCompleted = false
    @AppStorage(OnboardingState.listsCompletedKey) private var listsCompleted = false
    
    private let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    private var showOnboarding: Bool {
        !introSeen || !streamingCompleted || !podcastCompleted || !listsCompleted
    }
    
    var body: some View {
        ZStack {
            content
            if showOnboarding {
                NewUserExperienceView()
            }
        }
    }
}

#endif
