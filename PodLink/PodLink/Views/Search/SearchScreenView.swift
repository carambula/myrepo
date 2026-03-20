import SwiftUI

struct SearchScreenView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("searchBarAppearance") private var searchBarStyle = "glass"

    @State private var searchText = ""
    @State private var searchScope: SearchScope = .discover
    @State private var searchResults: [Podcast] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    enum SearchScope: String, CaseIterable {
        case library = "My Library"
        case discover = "Discover"
    }

    private var currentSearchBarStyle: SearchBarAppearance {
        SearchBarAppearance(rawValue: searchBarStyle) ?? .glass
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.lg)

            // Search bar
            HStack(spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    TextField("Search podcasts...", text: $searchText)
                        .font(DesignSystem.Typography.bodyMedium())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .searchBarStyle(currentSearchBarStyle)

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(GlassButtonStyle())
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            // Scope picker
            Picker("Scope", selection: $searchScope) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)

            // Results
            if isSearching {
                Spacer()
                ProgressView("Searching...")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Spacer()
            } else if searchResults.isEmpty && !searchText.isEmpty {
                Spacer()
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Results")
                        .font(DesignSystem.Typography.headlineLarge())
                        .foregroundColor(DesignSystem.Colors.headlineColor)
                    Text("Try a different search term.")
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Spacer()
            } else if searchResults.isEmpty {
                Spacer()
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(themeManager.currentTheme.accentColor.opacity(0.6))
                    Text("Find your next favorite podcast")
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Spacer()
            } else {
                SearchResultsView(results: searchResults)
            }
        }
        .background(themeManager.currentTheme.backgroundTint.opacity(0.3))
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                guard !Task.isCancelled else { return }
                await performSearch(query: newValue)
            }
        }
    }

    private func performSearch(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        do {
            switch searchScope {
            case .discover:
                searchResults = try await PodcastSearchService.shared.search(query: query)
            case .library:
                if let data = UserDefaults.standard.data(forKey: "followedPodcasts"),
                   let podcasts = try? JSONDecoder().decode([Podcast].self, from: data) {
                    let lowered = query.lowercased()
                    searchResults = podcasts.filter {
                        $0.title.lowercased().contains(lowered) ||
                        $0.author.lowercased().contains(lowered)
                    }
                }
            }
        } catch {
            searchResults = []
        }
        isSearching = false
    }
}
