import SwiftUI

struct ContentView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("miniPlayerDockMode") private var miniPlayerDockMode = "floating"
    
    @State private var showAccountSheet = false
    @State private var showSearch = false
    @State private var selectedPodcast: Podcast?
    @State private var selectedEpisode: Episode?
    @State private var showFullPlayer = false
    
    private var isDocked: Bool {
        miniPlayerDockMode == "docked"
    }

    var body: some View {
        ZStack(alignment: isDocked ? .top : .bottom) {
            if hasCompletedOnboarding {
                VStack(spacing: 0) {
                    if isDocked && playbackService.state.currentEpisode != nil {
                        MiniPlayerView(showFullPlayer: $showFullPlayer)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    PodcastListView(
                        showAccountSheet: $showAccountSheet,
                        showSearch: $showSearch,
                        selectedPodcast: $selectedPodcast
                    )
                }

                if !isDocked {
                    VStack(spacing: 0) {
                        if playbackService.state.currentEpisode != nil {
                            MiniPlayerView(showFullPlayer: $showFullPlayer)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
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
