import Foundation
import CoreGraphics

/// Shared grid ↔ list switching for the main followed-podcasts screen.
/// Matches the floating toggle: poster grid (no titles) ↔ titled list.
///
/// Swipe uses a card-slide reveal: either horizontal direction peels the current
/// layout away and shows the other underneath.
enum MainScreenLayoutToggle {
    /// Horizontal travel (points) that maps to a full 0→1 card reveal.
    static let interactiveSwipeDistance: CGFloat = 160
    /// Progress at which release commits to the other layout.
    static let commitProgress: Double = 0.5
    static let swipeAnimationDuration: TimeInterval = 0.25
    /// How far the top card travels off-screen when a swipe commits.
    static let dismissDistance: CGFloat = 420

    static func isGridPosterStyle(layoutMode: String, showTitles: Bool) -> Bool {
        layoutMode == "grid" && !showTitles
    }

    /// Destination mode for a toggle from the current poster/list style.
    static func otherMode(fromGridPoster: Bool) -> String {
        fromGridPoster ? "list" : "grid"
    }

    /// Locks onto either left or right when horizontal motion dominates.
    /// Returns `-1` (left) or `+1` (right), or `nil` if the gesture looks like a scroll.
    static func cardSwipeSign(
        translation: CGSize,
        axisLockMinimum: CGFloat = 24,
        horizontalDominance: CGFloat = 1.4
    ) -> CGFloat? {
        let dx = translation.width
        let dy = translation.height
        guard abs(dx) >= axisLockMinimum else { return nil }
        guard abs(dx) >= abs(dy) * horizontalDominance else { return nil }
        return dx < 0 ? -1 : 1
    }

    /// 0…1 reveal progress from absolute horizontal travel.
    static func cardSwipeProgress(
        translationWidth: CGFloat,
        distance: CGFloat = interactiveSwipeDistance
    ) -> Double {
        guard distance > 0 else { return 0 }
        return min(1, Double(abs(translationWidth) / distance))
    }

    /// Commit past halfway or with enough predicted momentum in the locked direction.
    /// Releasing early or reversing cancels.
    static func shouldCommitCardSwipe(
        progress: Double,
        translationWidth: CGFloat,
        predictedTranslationWidth: CGFloat,
        lockedSign: CGFloat,
        distance: CGFloat = interactiveSwipeDistance
    ) -> Bool {
        if progress >= commitProgress { return true }
        let predictedSameDirection = predictedTranslationWidth * lockedSign > 0
        let predictedProgress = cardSwipeProgress(
            translationWidth: predictedTranslationWidth,
            distance: distance
        )
        if predictedSameDirection, predictedProgress >= commitProgress { return true }
        if translationWidth * lockedSign < 0 { return false }
        return false
    }

    static func applyToggle(
        layoutMode: inout String,
        showTitles: inout Bool,
        artEmphasis: inout String
    ) {
        if isGridPosterStyle(layoutMode: layoutMode, showTitles: showTitles) {
            layoutMode = "list"
            showTitles = true
        } else {
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
        applyToggle(layoutMode: &layoutMode, showTitles: &showTitles, artEmphasis: &artEmphasis)
    }
}
