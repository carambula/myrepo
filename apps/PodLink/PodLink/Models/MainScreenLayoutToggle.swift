import Foundation

/// Shared grid ↔ list switching for the main followed-podcasts screen.
/// Matches the floating toggle: poster grid (no titles) ↔ titled list.
enum MainScreenLayoutToggle {
    enum SwipeDirection {
        /// Finger moves left — advance from poster grid to list.
        case towardList
        /// Finger moves right — return from list to poster grid.
        case towardGrid
    }

    static func isGridPosterStyle(layoutMode: String, showTitles: Bool) -> Bool {
        layoutMode == "grid" && !showTitles
    }

    /// Interprets a drag translation as a layout swipe, or `nil` if it looks like a scroll/tap.
    static func swipeDirection(
        translation: CGSize,
        minimumDistance: CGFloat = 64,
        horizontalDominance: CGFloat = 1.6
    ) -> SwipeDirection? {
        let dx = translation.width
        let dy = translation.height
        guard abs(dx) >= minimumDistance else { return nil }
        guard abs(dx) >= abs(dy) * horizontalDominance else { return nil }
        return dx < 0 ? .towardList : .towardGrid
    }

    static func apply(
        _ direction: SwipeDirection,
        layoutMode: inout String,
        showTitles: inout Bool,
        artEmphasis: inout String
    ) {
        switch direction {
        case .towardList:
            guard isGridPosterStyle(layoutMode: layoutMode, showTitles: showTitles) else { return }
            layoutMode = "list"
            showTitles = true
        case .towardGrid:
            guard !isGridPosterStyle(layoutMode: layoutMode, showTitles: showTitles) else { return }
            layoutMode = "grid"
            showTitles = false
        }
        artEmphasis = MainScreenArtEmphasis.largeArt.rawValue
    }

    static func toggle(
        layoutMode: inout String,
        showTitles: inout Bool,
        artEmphasis: inout String
    ) {
        if isGridPosterStyle(layoutMode: layoutMode, showTitles: showTitles) {
            apply(.towardList, layoutMode: &layoutMode, showTitles: &showTitles, artEmphasis: &artEmphasis)
        } else {
            apply(.towardGrid, layoutMode: &layoutMode, showTitles: &showTitles, artEmphasis: &artEmphasis)
        }
    }

    /// Y-axis degrees for a horizontal card flip. Outbound rotates to edge-on; inbound
    /// starts from the opposite edge-on so the new layout opens facing the user.
    static func flipAngles(from fromMode: String, to toMode: String) -> (outbound: Double, inbound: Double) {
        let direction: SwipeDirection =
            (fromMode == "grid" && toMode != "grid") ? .towardList : .towardGrid
        return flipAngles(for: direction)
    }

    static func flipAngles(for direction: SwipeDirection) -> (outbound: Double, inbound: Double) {
        switch direction {
        case .towardList:
            // Swipe left: rotate so the right face swings away, then open from -90°.
            return (90, -90)
        case .towardGrid:
            return (-90, 90)
        }
    }

    static let flipHalfDuration: TimeInterval = 0.2
}
