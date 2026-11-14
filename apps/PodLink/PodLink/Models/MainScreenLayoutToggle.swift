import Foundation
import CoreGraphics

/// Shared grid ↔ list switching for the main followed-podcasts screen.
/// Matches the floating toggle: poster grid (no titles) ↔ titled list.
///
/// Layouts sit side-by-side in a horizontal pager (grid | list). Each page
/// keeps its own scroll position. Shared chrome blur lerps between the two
/// pages' scroll offsets while the pager moves.
enum MainScreenLayoutToggle {
    /// Horizontal travel (as a fraction of page width) that commits on release.
    static let commitProgress: Double = 0.5
    static let swipeAnimationDuration: TimeInterval = 0.28
    /// Minimum horizontal movement before the pager steals the gesture from scroll.
    static let axisLockMinimum: CGFloat = 24
    static let horizontalDominance: CGFloat = 1.4

    static func isGridPosterStyle(layoutMode: String, showTitles: Bool) -> Bool {
        layoutMode == "grid" && !showTitles
    }

    /// Destination mode for a toggle from the current poster/list style.
    static func otherMode(fromGridPoster: Bool) -> String {
        fromGridPoster ? "list" : "grid"
    }

    /// Page index in the abutted pager: grid = 0, list = 1.
    static func pageIndex(forLayoutMode mode: String) -> CGFloat {
        mode == "list" ? 1 : 0
    }

    /// Locks onto horizontal motion when it dominates vertical scroll.
    /// Returns the translation width once locked, or `nil` if still a scroll.
    static func pagerAxisLockTranslation(
        translation: CGSize,
        axisLockMinimum: CGFloat = axisLockMinimum,
        horizontalDominance: CGFloat = horizontalDominance
    ) -> CGFloat? {
        let dx = translation.width
        let dy = translation.height
        guard abs(dx) >= axisLockMinimum else { return nil }
        guard abs(dx) >= abs(dy) * horizontalDominance else { return nil }
        return dx
    }

    /// 0…1 how far the pager has moved from grid toward list.
    static func pagerProgress(offset: CGFloat, pageWidth: CGFloat) -> CGFloat {
        guard pageWidth > 0 else { return 0 }
        return min(1, max(0, -offset / pageWidth))
    }

    /// Clamp the HStack offset so pages stay abutted within [−width, 0].
    static func clampedPagerOffset(
        settledIndex: CGFloat,
        dragTranslation: CGFloat,
        pageWidth: CGFloat
    ) -> CGFloat {
        guard pageWidth > 0 else { return 0 }
        let raw = -settledIndex * pageWidth + dragTranslation
        return min(0, max(-pageWidth, raw))
    }

    /// Commit when released past halfway (or with predicted momentum past halfway).
    static func shouldCommitPagerSwipe(
        fromIndex: CGFloat,
        toOffset: CGFloat,
        predictedOffset: CGFloat,
        pageWidth: CGFloat,
        commitProgress: Double = commitProgress
    ) -> Bool {
        guard pageWidth > 0 else { return false }
        let currentProgress = Double(pagerProgress(offset: toOffset, pageWidth: pageWidth))
        let predictedProgress = Double(pagerProgress(offset: predictedOffset, pageWidth: pageWidth))
        let targetIsList = fromIndex < 0.5
        if targetIsList {
            return currentProgress >= commitProgress || predictedProgress >= commitProgress
        }
        return currentProgress <= (1 - commitProgress) || predictedProgress <= (1 - commitProgress)
    }

    /// Chrome blur/fade progress from a page's scroll offset.
    static func scrollBlurProgress(
        scrollOffset: CGFloat,
        blurDistance: CGFloat = 80
    ) -> CGFloat {
        guard blurDistance > 0 else { return 0 }
        return min(1, max(0, scrollOffset / blurDistance))
    }

    /// Blend chrome blur between the two pages using pager progress (0 = grid, 1 = list).
    static func blendedChromeBlurProgress(
        gridScrollOffset: CGFloat,
        listScrollOffset: CGFloat,
        pagerProgress: CGFloat,
        blurDistance: CGFloat = 80
    ) -> CGFloat {
        let grid = scrollBlurProgress(scrollOffset: gridScrollOffset, blurDistance: blurDistance)
        let list = scrollBlurProgress(scrollOffset: listScrollOffset, blurDistance: blurDistance)
        let t = min(1, max(0, pagerProgress))
        return grid + (list - grid) * t
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

    /// Grid tile titles — settled titled-grid only; never mid-pager swipe.
    static func gridShowsTitles(
        layoutMode: String,
        showTitles: Bool,
        isPagerActive: Bool
    ) -> Bool {
        guard layoutMode == "grid", !isPagerActive else { return false }
        return showTitles
    }

    /// List page always shows titles (poster ↔ titled-list toggle).
    static func listShowsTitles(isListPage: Bool) -> Bool {
        isListPage
    }
}
