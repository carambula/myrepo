import SwiftUI

struct RaceFiltersView: View {
    @Binding var filters: RaceFilters

    var body: some View {
        NavigationStack {
            Form {
                Section("Dates") {
                    TextField("Start date (YYYY-MM-DD)", text: Binding(
                        get: { filters.startDate ?? "" },
                        set: { filters.startDate = $0.isEmpty ? nil : $0 }
                    ))
                    .font(DesignSystem.Typography.bodyMedium)
                    TextField("End date (YYYY-MM-DD)", text: Binding(
                        get: { filters.endDate ?? "" },
                        set: { filters.endDate = $0.isEmpty ? nil : $0 }
                    ))
                    .font(DesignSystem.Typography.bodyMedium)
                }
                .listRowBackground(DesignSystem.Color.groupedListCardBackground)

                Section("Categories") {
                    TextField("Series", text: Binding(
                        get: { filters.series ?? "" },
                        set: { filters.series = $0.isEmpty ? nil : $0 }
                    ))
                    .font(DesignSystem.Typography.bodyMedium)
                    TextField("Discipline", text: Binding(
                        get: { filters.discipline ?? "" },
                        set: { filters.discipline = $0.isEmpty ? nil : $0 }
                    ))
                    .font(DesignSystem.Typography.bodyMedium)
                    TextField("Race type", text: Binding(
                        get: { filters.raceType ?? "" },
                        set: { filters.raceType = $0.isEmpty ? nil : $0 }
                    ))
                    .font(DesignSystem.Typography.bodyMedium)
                    TextField("Gender division", text: Binding(
                        get: { filters.genderDivision ?? "" },
                        set: { filters.genderDivision = $0.isEmpty ? nil : $0 }
                    ))
                    .font(DesignSystem.Typography.bodyMedium)
                }
                .listRowBackground(DesignSystem.Color.groupedListCardBackground)

                Section("Limits") {
                    Stepper("Max results: \(filters.limit)", value: $filters.limit, in: 10...200, step: 10)
                        .font(DesignSystem.Typography.labelMedium)
                }
                .listRowBackground(DesignSystem.Color.groupedListCardBackground)
            }
            .designSystemGroupedListStyle()
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        filters = RaceFilters()
                    }
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Color.accent)
                }
            }
            .themeBackground()
        }
    }
}
