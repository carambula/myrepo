//
//  SearchFilterMenus.swift
//  WatchedIt
//
//  Created by Cursor on 3/1/26.
//

import SwiftUI

struct SearchFilterMenus: View {
    enum Presentation {
        case overflowButton
        case lifestyleIcons
    }

    @Binding var filters: MovieSearchFilters
    let allowsListFilter: Bool
    let availableGenres: [String]
    let availableMPAARatings: [String]
    let availableStreamingServices: [String]
    let availablePeriods: [Int]
    let availablePhysicalMediaFilters: [PhysicalMediaFilter]
    let preferredStreamingServices: [String]
    let preferredDataSources: [DataSource]
    let controlSize: CGFloat
    let presentation: Presentation
    @AppStorage(MainListToolbarStyle.storageKey) private var mainListToolbarStyleRaw: String = MainListToolbarStyle.system.rawValue

    init(
        filters: Binding<MovieSearchFilters>,
        allowsListFilter: Bool,
        availableGenres: [String],
        availableMPAARatings: [String],
        availableStreamingServices: [String],
        availablePeriods: [Int] = [],
        availablePhysicalMediaFilters: [PhysicalMediaFilter] = [],
        preferredStreamingServices: [String],
        preferredDataSources: [DataSource],
        controlSize: CGFloat = 48,
        presentation: Presentation = .overflowButton
    ) {
        self._filters = filters
        self.allowsListFilter = allowsListFilter
        self.availableGenres = availableGenres
        self.availableMPAARatings = availableMPAARatings
        self.availableStreamingServices = availableStreamingServices
        self.availablePeriods = availablePeriods
        self.availablePhysicalMediaFilters = availablePhysicalMediaFilters
        self.preferredStreamingServices = preferredStreamingServices
        self.preferredDataSources = preferredDataSources
        self.controlSize = controlSize
        self.presentation = presentation
    }

    var body: some View {
        switch presentation {
        case .overflowButton:
            overflowMenu
        case .lifestyleIcons:
            lifestyleIcons
        }
    }

    private var overflowMenu: some View {
        Menu {
            overflowMenuContent
        } label: {
            GlassCircleButton(systemImage: DesignSystem.Icon.filter, foregroundColor: filterIconColor, accessibilityLabel: "Filters")
        }
    }

    @ViewBuilder
    private var overflowMenuContent: some View {
        Menu {
            statusMenuContent
        } label: {
            Label("Status", systemImage: DesignSystem.Icon.status)
        }
        if allowsListFilter {
            Menu {
                listMenuContent
            } label: {
                Label("Lists", systemImage: DesignSystem.Icon.listRectangle)
            }
        }
        if showsStreamingMenu {
            Menu {
                streamingMenuContent
            } label: {
                Label("Streaming", systemImage: "play.square.stack.fill")
            }
        }
        Menu {
            theatricalMenuContent
        } label: {
            Label("Theaters", systemImage: DesignSystem.Icon.ticket)
        }
        if !availablePhysicalMediaFilters.isEmpty {
            Menu {
                physicalMediaMenuContent
            } label: {
                Label("Discs", systemImage: DesignSystem.Icon.disc)
            }
        }
        if !availablePeriods.isEmpty {
            Menu {
                periodMenuContent
            } label: {
                Label("Periods", systemImage: DesignSystem.Icon.calendar)
            }
        }
        Menu {
            genreMenuContent
        } label: {
            Label("Genres", systemImage: DesignSystem.Icon.genre)
        }
        Menu {
            mpaaMenuContent
        } label: {
            Label("Ratings", systemImage: DesignSystem.Icon.rating)
        }
    }

    private var lifestyleIcons: some View {
        HStack(spacing: DesignSystem.Spacing.xl) {
            Menu {
                statusMenuContent
            } label: {
                lifestyleIcon(DesignSystem.Icon.status, isActive: filters.watchFilter != .all)
            }
            .accessibilityLabel("Status")

            if allowsListFilter {
                Menu {
                    listMenuContent
                } label: {
                    lifestyleIcon(DesignSystem.Icon.listRectangle, isActive: filters.selectedListIdentifier != nil)
                }
                .accessibilityLabel("Lists")
            }

            if showsStreamingMenu {
                Menu {
                    streamingMenuContent
                } label: {
                    lifestyleIcon("play.square.stack.fill", isActive: filters.selectedStreamingService != nil)
                }
                .accessibilityLabel("Streaming")
            }

            Menu {
                theatricalMenuContent
            } label: {
                lifestyleIcon(DesignSystem.Icon.ticket, isActive: filters.theatricalFilter != nil)
            }
            .accessibilityLabel("Theaters")

            if !availablePhysicalMediaFilters.isEmpty {
                Menu {
                    physicalMediaMenuContent
                } label: {
                    lifestyleIcon(DesignSystem.Icon.disc, isActive: filters.physicalMediaFilter != nil)
                }
                .accessibilityLabel("Discs")
            }

            if !availablePeriods.isEmpty {
                Menu {
                    periodMenuContent
                } label: {
                    lifestyleIcon(DesignSystem.Icon.calendar, isActive: filters.selectedPeriod != nil)
                }
                .accessibilityLabel("Periods")
            }

            Menu {
                genreMenuContent
            } label: {
                lifestyleIcon(DesignSystem.Icon.genre, isActive: filters.selectedGenre != nil)
            }
            .accessibilityLabel("Genres")

            Menu {
                mpaaMenuContent
            } label: {
                lifestyleIcon(DesignSystem.Icon.rating, isActive: filters.selectedMPAARating != nil)
            }
            .accessibilityLabel("Ratings")
        }
    }

    private var showsStreamingMenu: Bool {
        !availableStreamingServices.isEmpty || !preferredStreamingServices.isEmpty
    }

    private func lifestyleIcon(_ systemName: String, isActive: Bool) -> some View {
        DesignSystemIcon(
            systemName,
            size: DesignSystem.IconSize.md,
            color: isActive ? DesignSystem.Color.accent : lifestyleIconColor
        )
    }

    private var lifestyleIconColor: Color {
        usesCustomFloatingToolbar ? toolbarSecondaryAccentColor : DesignSystem.Color.textPrimary
    }

    private var hasActiveControls: Bool {
        filters.watchFilter != .all
            || filters.selectedGenre != nil
            || filters.selectedMPAARating != nil
            || filters.selectedStreamingService != nil
            || filters.theatricalFilter != nil
            || filters.physicalMediaFilter != nil
            || filters.selectedPeriod != nil
            || (allowsListFilter && filters.selectedListIdentifier != nil)
    }

    private var filterIconColor: Color {
        if usesCustomFloatingToolbar {
            return hasActiveControls ? DesignSystem.Color.accent : toolbarSecondaryAccentColor
        }
        return hasActiveControls ? DesignSystem.Color.accent : DesignSystem.Color.textPrimary
    }

    private var usesCustomFloatingToolbar: Bool {
        #if os(iOS)
        return mainListToolbarStyle == .customFloating
        #else
        return false
        #endif
    }

    private var mainListToolbarStyle: MainListToolbarStyle {
        MainListToolbarStyle(rawValue: mainListToolbarStyleRaw) ?? .system
    }

    private var toolbarSecondaryAccentColor: Color {
        DesignSystem.Color.secondaryAccent ?? DesignSystem.Color.accent
    }

    @ViewBuilder
    private var statusMenuContent: some View {
        ForEach(WatchFilter.allCases, id: \.self) { filter in
            Button {
                updateFilters { $0.watchFilter = filter }
            } label: {
                if filters.watchFilter == filter {
                    Label(filter.rawValue, systemImage: DesignSystem.Icon.checkmark)
                } else {
                    Label(filter.rawValue, systemImage: filter.systemImage)
                }
            }
        }
    }

    @ViewBuilder
    private var genreMenuContent: some View {
        Button("All Genres") {
            updateFilters { $0.selectedGenre = nil }
        }
        ForEach(availableGenres, id: \.self) { genre in
            Button {
                updateFilters { $0.selectedGenre = genre }
            } label: {
                if filters.selectedGenre == genre {
                    Label(genre, systemImage: "checkmark")
                } else {
                    Text(genre)
                }
            }
        }
    }

    @ViewBuilder
    private var mpaaMenuContent: some View {
        Button("All Ratings") {
            updateFilters { $0.selectedMPAARating = nil }
        }
        ForEach(availableMPAARatings, id: \.self) { rating in
            Button {
                updateFilters { $0.selectedMPAARating = rating }
            } label: {
                if filters.selectedMPAARating == rating {
                    Label(rating, systemImage: "checkmark")
                } else {
                    Text(rating)
                }
            }
        }
    }

    @ViewBuilder
    private var listMenuContent: some View {
        Button {
            updateFilters {
                $0.selectedListIdentifier = nil
                $0.sortOption = .episodeDateDesc
            }
        } label: {
            if filters.selectedListIdentifier == nil {
                Label("All Lists", systemImage: "checkmark")
            } else {
                Text("All Lists")
            }
        }
        if !preferredDataSources.isEmpty {
            Divider()
            ForEach(preferredDataSources, id: \.identifier) { source in
                Button {
                    updateFilters {
                        $0.selectedListIdentifier = source.identifier
                        if source.isRankedList {
                            $0.sortOption = .ranking
                        }
                    }
                } label: {
                    if filters.selectedListIdentifier == source.identifier {
                        Label(source.name, systemImage: "checkmark")
                    } else {
                        Text(source.name)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var streamingMenuContent: some View {
        Button("All Services") {
            updateFilters { $0.selectedStreamingService = nil }
        }
        if !preferredStreamingServices.isEmpty {
            Divider()
            ForEach(preferredStreamingServices, id: \.self) { service in
                Button {
                    updateFilters { $0.selectedStreamingService = service }
                } label: {
                    if filters.selectedStreamingService == service {
                        Label(service, systemImage: "checkmark")
                    } else {
                        Text(service)
                    }
                }
            }
            Divider()
            Button {
                updateFilters { $0.selectedStreamingService = "My Services" }
            } label: {
                if filters.selectedStreamingService == "My Services" {
                    Label("My Services", systemImage: "checkmark")
                } else {
                    Text("My Services")
                }
            }
        }
    }

    @ViewBuilder
    var physicalMediaMenuContent: some View {
        Button("All Discs") {
            updateFilters { $0.physicalMediaFilter = nil }
        }
        if !availableFormats.isEmpty {
            Section("Physical Media") {
                ForEach(availableFormats, id: \.self) { filter in
                    physicalMediaFilterButton(filter)
                }
            }
        }
        if !availablePartnerships.isEmpty {
            Section("Partnerships") {
                ForEach(availablePartnerships, id: \.self) { filter in
                    physicalMediaFilterButton(filter)
                }
            }
        }
    }

    private var availableFormats: [PhysicalMediaFilter] {
        PhysicalMediaFilter.formats.filter { availablePhysicalMediaFilters.contains($0) }
    }

    private var availablePartnerships: [PhysicalMediaFilter] {
        PhysicalMediaFilter.partnerships.filter { availablePhysicalMediaFilters.contains($0) }
    }

    @ViewBuilder
    private func physicalMediaFilterButton(_ filter: PhysicalMediaFilter) -> some View {
        Button {
            updateFilters { $0.physicalMediaFilter = filter }
        } label: {
            if filters.physicalMediaFilter == filter {
                Label(filter.rawValue, systemImage: "checkmark")
            } else {
                Text(filter.rawValue)
            }
        }
    }

    @ViewBuilder
    var periodMenuContent: some View {
        Button("All Periods") {
            updateFilters { $0.selectedPeriod = nil }
        }
        ForEach(availablePeriods, id: \.self) { decade in
            Button {
                updateFilters {
                    $0.selectedPeriod = decade
                    $0.selectedReleaseYear = nil
                }
            } label: {
                let label = ReleasePeriod(decade: decade).label
                if filters.selectedPeriod == decade {
                    Label(label, systemImage: "checkmark")
                } else {
                    Text(label)
                }
            }
        }
    }

    @ViewBuilder
    private var theatricalMenuContent: some View {
        Button("All Movies") {
            updateFilters { $0.theatricalFilter = nil }
        }
        ForEach(TheatricalFilter.allCases, id: \.self) { filter in
            Button {
                updateFilters { $0.theatricalFilter = filter }
            } label: {
                if filters.theatricalFilter == filter {
                    Label(filter.rawValue, systemImage: "checkmark")
                } else {
                    Text(filter.rawValue)
                }
            }
        }
    }

    private func updateFilters(_ mutate: (inout MovieSearchFilters) -> Void) {
        var updated = filters
        mutate(&updated)
        filters = updated
    }
}
