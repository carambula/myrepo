import Foundation

/// Controls which latest-episode condition triggers the accent dot on the main grid/list.
enum NewEpisodeBadgeMode: String, CaseIterable {
    case off
    case unfinishedRecent
    case notStartedRecent
    case unfinishedLatest
    case notStartedLatest

    var displayName: String {
        switch self {
        case .off:               return "Off"
        case .unfinishedRecent:  return "Unfinished & recent"
        case .notStartedRecent:  return "Not started & recent"
        case .unfinishedLatest:  return "Latest unfinished"
        case .notStartedLatest:  return "Latest not started"
        }
    }

    var description: String {
        switch self {
        case .off:
            return "No badge is shown."
        case .unfinishedRecent:
            return "Show when the latest episode was published in the last 24 hours and is not finished."
        case .notStartedRecent:
            return "Show when the latest episode was published in the last 24 hours and has not been started."
        case .unfinishedLatest:
            return "Show when the latest episode has not been finished."
        case .notStartedLatest:
            return "Show when the latest episode has not been started."
        }
    }

    func shouldShowBadge(for episode: Episode?) -> Bool {
        guard let episode, self != .off else { return false }
        switch self {
        case .off:
            return false
        case .unfinishedRecent:
            return episode.publishDate.timeIntervalSinceNow > -86400
                && !episode.isEffectivelyFinished
        case .notStartedRecent:
            return episode.publishDate.timeIntervalSinceNow > -86400
                && !episode.hasBeenListenedTo
        case .unfinishedLatest:
            return !episode.isEffectivelyFinished
        case .notStartedLatest:
            return !episode.hasBeenListenedTo
        }
    }
}

/// Main (followed podcasts) screen grid emphasis — pairs with `posterSize` for grid artwork dimensions.
enum MainScreenArtEmphasis: String, CaseIterable {
    case standard
    case largeArt

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .largeArt: return "Large artwork"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "Default tile size for the selected artwork scale."
        case .largeArt:
            return "Larger cover art in grid and list rows."
        }
    }

    /// Extra points added to base grid artwork size when `largeArt` is selected.
    static let largeArtGridBonus: CGFloat = 28

    /// List row artwork side length: standard matches episode-row feel; large is closer to grid tiles.
    func listArtworkSideLength(baseListSize: CGFloat = 60) -> CGFloat {
        switch self {
        case .standard: return baseListSize
        case .largeArt: return baseListSize + 20
        }
    }
}
