import Foundation
import CoreGraphics

/// Shared grid ↔ list switching for the main followed-podcasts screen.
/// Matches the floating toggle: poster grid (no titles) ↔ titled list.
enum MainScreenLayoutToggle {
    enum SwipeDirection {
        /// Finger moves left — advance from poster grid to list.
        case towardList
        /// Finger moves right — return from list to poster grid.
        case towardGrid
    }

    /// Horizontal travel (points) that maps to a full 0→1 flip.
    static let interactiveFlipDistance: CGFloat = 180
    /// Progress at which release commits to the destination layout.
    static let commitProgress: Double = 0.5
    /// Predicted end progress at/above this also commits (flick / momentum).
    static let commitPredictedProgress: Double = 0.5

    static let flipAnimationDuration: TimeInterval = 0.28

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

    /// Allowed interactive direction from the current poster/list style, if any.
    static func interactiveDirection(
        translation: CGSize,
        fromGridPoster: Bool,
        axisLockMinimum: CGFloat = 24,
        horizontalDominance: CGFloat = 1.4
    ) -> SwipeDirection? {
        let dx = translation.width
        let dy = translation.height
        guard abs(dx) >= axisLockMinimum else { return nil }
        guard abs(dx) >= abs(dy) * horizontalDominance else { return nil }
        if fromGridPoster {
            return dx < 0 ? .towardList : nil
        }
        return dx > 0 ? .towardGrid : nil
    }

    /// 0…1 flip progress from finger travel in the locked direction.
    static func interactiveProgress(
        translationWidth: CGFloat,
        direction: SwipeDirection,
        distance: CGFloat = interactiveFlipDistance
    ) -> Double {
        guard distance > 0 else { return 0 }
        let traveled: CGFloat
        switch direction {
        case .towardList:
            traveled = max(0, -translationWidth)
        case .towardGrid:
            traveled = max(0, translationWidth)
        }
        return min(1, Double(traveled / distance))
    }

    /// Commit when past halfway, or when predicted end travel would finish the flip.
    /// Releasing below halfway (or flicking back) cancels.
    static func shouldCommit(
        progress: Double,
        translationWidth: CGFloat,
        predictedTranslationWidth: CGFloat,
        direction: SwipeDirection,
        distance: CGFloat = interactiveFlipDistance
    ) -> Bool {
        if progress >= commitProgress { return true }
        let predicted = interactiveProgress(
            translationWidth: predictedTranslationWidth,
            direction: direction,
            distance: distance
        )
        if predicted >= commitPredictedProgress { return true }
        // Explicit reverse past the start: cancel.
        let opposing: Bool
        switch direction {
        case .towardList:
            opposing = translationWidth > 0
        case .towardGrid:
            opposing = translationWidth < 0
        }
        if opposing { return false }
        return false
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
    ///
    /// Direction matches the finger: swipe left (toward list) rotates with the finger
    /// (negative Y), swipe right (toward grid) the opposite way.
    static func flipAngles(from fromMode: String, to toMode: String) -> (outbound: Double, inbound: Double) {
        let direction: SwipeDirection =
            (fromMode == "grid" && toMode != "grid") ? .towardList : .towardGrid
        return flipAngles(for: direction)
    }

    static func flipAngles(for direction: SwipeDirection) -> (outbound: Double, inbound: Double) {
        switch direction {
        case .towardList:
            return (-90, 90)
        case .towardGrid:
            return (90, -90)
        }
    }

    /// Continuous 0…1 progress → Y rotation, swapping faces at the halfway edge-on point.
    static func rotationDegrees(progress: Double, direction: SwipeDirection) -> Double {
        let angles = flipAngles(for: direction)
        let p = min(1, max(0, progress))
        if p < 0.5 {
            return angles.outbound * (p / 0.5)
        }
        let t = (p - 0.5) / 0.5
        return angles.inbound * (1 - t)
    }

    static func showsDestination(progress: Double) -> Bool {
        progress >= 0.5
    }

    static func sourceMode(for direction: SwipeDirection) -> String {
        direction == .towardList ? "grid" : "list"
    }

    static func destinationMode(for direction: SwipeDirection) -> String {
        direction == .towardList ? "list" : "grid"
    }
}
