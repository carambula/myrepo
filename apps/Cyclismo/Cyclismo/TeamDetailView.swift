import SwiftUI

struct TeamDetailView: View {
    let teamId: String
    @State private var team: Team?
    @State private var upcomingRaces: [Race] = []
    @State private var errorMessage: String?
    @State private var selectedRace: Race?

    var body: some View {
        List {
            if let team {
                Section("Overview") {
                    LabeledContent("Name", value: team.name)
                    if let uciCode = team.uciCode {
                        LabeledContent("UCI code", value: uciCode)
                    }
                    LabeledContent("Discipline", value: team.discipline)
                    if let region = team.region {
                        LabeledContent("Region", value: region)
                    }
                }
                .font(DesignSystem.Typography.bodyMedium)
                .listRowBackground(DesignSystem.Color.groupedListCardBackground)

                if let website = team.website, let url = URL(string: website) {
                    Section("Links") {
                        Link(destination: url) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                DesignSystemIcon(DesignSystem.Icon.link, size: DesignSystem.IconSize.sm, color: DesignSystem.Color.accent)
                                Text("Team website")
                                    .labelMedium()
                                    .foregroundColor(DesignSystem.Color.accent)
                            }
                        }
                    }
                    .listRowBackground(DesignSystem.Color.groupedListCardBackground)
                }

                Section("Upcoming races") {
                    if upcomingRaces.isEmpty {
                        Text("No upcoming races yet.")
                            .bodyMedium()
                            .foregroundColor(DesignSystem.Color.textSecondary)
                    } else {
                        ForEach(upcomingRaces) { race in
                            Button {
                                selectedRace = race
                            } label: {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(race.name)
                                        .headlineSmall()
                                        .foregroundHeadline()
                                    Text("\(race.startDate) • \(race.locationCity ?? "TBD")")
                                        .captionMedium()
                                        .foregroundColor(DesignSystem.Color.textSecondary)
                                }
                                .padding(.vertical, DesignSystem.Spacing.xs)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xs, leading: DesignSystem.Spacing.lg, bottom: DesignSystem.Spacing.xs, trailing: DesignSystem.Spacing.lg))
                            .listRowBackground(DesignSystem.Color.groupedListCardBackground)
                        }
                    }
                }
                .listRowBackground(DesignSystem.Color.groupedListCardBackground)
            } else {
                ContentUnavailableView {
                    ProgressView()
                        .scaleEffect(1.2)
                } description: {
                    Text("Loading team...")
                        .labelMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
            }
        }
        .designSystemGroupedListStyle()
        .navigationTitle(team?.name ?? "Team")
        .sheet(item: $selectedRace) { race in
            RaceDetailView(race: race)
        }
        .refreshable {
            APIClient.shared.clearCache()
            await loadTeam()
        }
        .task {
            await loadTeam()
        }
        .alert("Unable to load team", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .themeBackground()
    }

    private func loadTeam() async {
        do {
            team = try await APIClient.shared.fetchTeam(id: teamId)
            upcomingRaces = try await APIClient.shared.fetchTeamRaces(id: teamId, upcomingOnly: true)
        } catch {
            errorMessage = "Please check that the API is running."
        }
    }
}
