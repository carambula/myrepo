import SwiftUI

struct AthleteDetailView: View {
    let athleteId: String
    @State private var athlete: Athlete?
    @State private var upcomingRaces: [Race] = []
    @State private var errorMessage: String?
    @State private var selectedRace: Race?

    var body: some View {
        List {
            if let athlete {
                Section("Overview") {
                    LabeledContent("Name", value: athlete.fullName)
                    if let nationality = athlete.nationality {
                        LabeledContent("Nationality", value: nationality)
                    }
                    if let discipline = athlete.discipline {
                        LabeledContent("Discipline", value: discipline)
                    }
                    if let dob = athlete.dob {
                        LabeledContent("Date of birth", value: dob)
                    }
                }
                .font(DesignSystem.Typography.bodyMedium)
                .listRowBackground(DesignSystem.Color.groupedListCardBackground)

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
                                    Text("\(race.startDate)   \(race.locationCity ?? "TBD")")
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
                    Text("Loading athlete...")
                        .labelMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
            }
        }
        .designSystemGroupedListStyle()
        .navigationTitle(athlete?.fullName ?? "Athlete")
        .sheet(item: $selectedRace) { race in
            RaceDetailView(race: race)
        }
        .refreshable {
            APIClient.shared.clearCache()
            await loadAthlete()
        }
        .task {
            await loadAthlete()
        }
        .alert("Unable to load athlete", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .themeBackground()
    }

    private func loadAthlete() async {
        do {
            athlete = try await APIClient.shared.fetchAthlete(id: athleteId)
            upcomingRaces = try await APIClient.shared.fetchAthleteRaces(id: athleteId, upcomingOnly: true)
        } catch {
            errorMessage = "Please check that the API is running."
        }
    }
}
