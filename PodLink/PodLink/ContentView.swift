import SwiftUI

struct ContentView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showAccountSheet = false
    @State private var showSearch = false
    @State private var selectedPodcast: Podcast?
    @State private var selectedEpisode: Episode?
    @State private var showFullPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if hasCompletedOnboarding {
                PodcastListView(
                    showAccountSheet: $showAccountSheet,
                    showSearch: $showSearch,
                    selectedPodcast: $selectedPodcast
                )

                VStack(spacing: 0) {
                    if playbackService.state.currentEpisode != nil {
                        MiniPlayerView(showFullPlayer: $showFullPlayer)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .sheet(item: $selectedPodcast) { podcast in
            PodcastDetailView(
                podcast: podcast,
                selectedEpisode: $selectedEpisode
            )
            .environment(themeManager)
            .environment(playbackService)
        }
        .sheet(item: $selectedEpisode) { episode in
            EpisodeDetailView(episode: episode)
                .environment(themeManager)
                .environment(playbackService)
        }
        .sheet(isPresented: $showFullPlayer) {
            FullPlayerView()
                .environment(themeManager)
                .environment(playbackService)
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheetView()
                .environment(themeManager)
                .environment(playbackService)
        }
        .sheet(isPresented: $showSearch) {
            SearchScreenView()
                .environment(themeManager)
                .environment(playbackService)
        }
        .animation(.spring(response: 0.35), value: playbackService.state.currentEpisode != nil)
    }
}
