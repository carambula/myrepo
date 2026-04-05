import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results = SearchResults(races: [], teams: [], athletes: [])
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRace: Race?

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ContentUnavailableView {
                        ProgressView()
                            .scaleEffect(1.2)
                    } description: {
                        Text("Searching...")
                            .labelMedium()
                            .foregroundColor(DesignSystem.Color.textSecondary)
                    }
                }

                if !results.races.isEmpty {
                    Section("Races") {
                        ForEach(results.races) { race in
                            Button {
                                selectedRace = race
                            } label: {
                                Text(race.name)
                                    .headlineSmall()
                                    .foregroundHeadline()
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xs, leading: DesignSystem.Spacing.lg, bottom: DesignSystem.Spacing.xs, trailing: DesignSystem.Spacing.lg))
                            .listRowBackground(DesignSystem.Color.groupedListCardBackground)
                        }
                    }
                }

                if !results.teams.isEmpty {
                    Section("Teams") {
                        ForEach(results.teams) { team in
                            NavigationLink(value: team) {
                                Text(team.name)
                                    .headlineSmall()
                                    .foregroundHeadline()
                            }
                            .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xs, leading: DesignSystem.Spacing.lg, bottom: DesignSystem.Spacing.xs, trailing: DesignSystem.Spacing.lg))
                            .listRowBackground(DesignSystem.Color.groupedListCardBackground)
                        }
                    }
                }

                if !results.athletes.isEmpty {
                    Section("Athletes") {
                        ForEach(results.athletes) { athlete in
                            NavigationLink(value: athlete) {
                                Text(athlete.fullName)
                                    .headlineSmall()
                                    .foregroundHeadline()
                            }
                            .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xs, leading: DesignSystem.Spacing.lg, bottom: DesignSystem.Spacing.xs, trailing: DesignSystem.Spacing.lg))
                            .listRowBackground(DesignSystem.Color.groupedListCardBackground)
                        }
                    }
                }

                if !isLoading && results.races.isEmpty && results.teams.isEmpty && results.athletes.isEmpty {
                    ContentUnavailableView(
                        "No results",
                        systemImage: DesignSystem.Icon.search,
                        description: Text("Try a different query.")
                            .foregroundColor(DesignSystem.Color.textSecondary)
                    )
                }
            }
            .designSystemGroupedListStyle()
            .navigationTitle("Search")
            .searchable(text: $query)
            .onSubmit(of: .search) {
                Task { await runSearch() }
            }
            .refreshable {
                APIClient.shared.clearCache()
                await runSearch()
            }
            .sheet(item: $selectedRace) { race in
                RaceDetailView(race: race)
            }
            .navigationDestination(for: Team.self) { team in
                TeamDetailView(teamId: team.teamId)
            }
            .navigationDestination(for: Athlete.self) { athlete in
                AthleteDetailView(athleteId: athlete.athleteId)
            }
            .alert("Unable to search", isPresented: Binding(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .themeBackground()
        }
    }

    private func runSearch() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            results = try await APIClient.shared.search(query: query)
        } catch {
            errorMessage = "Please check that the API is running."
        }
    }
}
