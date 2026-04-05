//
//  SearchFilterMenus.swift
//  WatchedIt
//
//  Created by Cursor on 3/1/26.
//

import SwiftUI

struct SearchFilterMenus: View {
    @Binding var filters: MovieSearchFilters
    let allowsListFilter: Bool
    let availableGenres: [String]
    let availableMPAARatings: [String]
    let availableStreamingServices: [String]
    let preferredStreamingServices: [String]
    let preferredDataSources: [DataSource]
    let controlSize: CGFloat
    @AppStorage(MainListToolbarStyle.storageKey) private var mainListToolbarStyleRaw: String = MainListToolbarStyle.system.rawValue

    init(
        filters: Binding<MovieSearchFilters>,
        allowsListFilter: Bool,
        availableGenres: [String],
        availableMPAARatings: [String],
        availableStreamingServices: [String],
        preferredStreamingServices: [String],
        preferredDataSources: [DataSource],
        controlSize: CGFloat = 48
    ) {
        self._filters = filters
        self.allowsListFilter = allowsListFilter
        self.availableGenres = availableGenres
        self.availableMPAARatings = availableMPAARatings
        self.availableStreamingServices = availableStreamingServices
        self.preferredStreamingServices = preferredStreamingServices
        self.preferredDataSources = preferredDataSources
        self.controlSize = controlSize
    }

    var body: some View {
        Menu {
            if allowsListFilter {
                Menu {
                    listMenuContent
                } label: {
                    Label("Lists", systemImage: DesignSystem.Icon.listRectangle)
                }
            }
            if !availableStreamingServices.isEmpty {
                Menu {
                    streamingMenuContent
                } label: {
                    Label("Streaming", systemImage: "play.square.stack.fill")
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
        } label: {
            GlassCircleButton(systemImage: DesignSystem.Icon.filter, foregroundColor: filterIconColor, accessibilityLabel: "Filters")
        }
    }

    private var hasActiveControls: Bool {
        filters.watchFilter != .all
            || filters.selectedGenre != nil
            || filters.selectedMPAARating != nil
            || filters.selectedStreamingService != nil
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

    private func updateFilters(_ mutate: (inout MovieSearchFilters) -> Void) {
        var updated = filters
        mutate(&updated)
        filters = updated
    }
}
