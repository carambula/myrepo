import Foundation
import Testing
@testable import PodLink

struct MainScreenLayoutToggleTests {
    @Test
    func detectsGridPosterStyle() {
        #expect(MainScreenLayoutToggle.isGridPosterStyle(layoutMode: "grid", showTitles: false))
        #expect(!MainScreenLayoutToggle.isGridPosterStyle(layoutMode: "grid", showTitles: true))
        #expect(!MainScreenLayoutToggle.isGridPosterStyle(layoutMode: "list", showTitles: true))
        #expect(!MainScreenLayoutToggle.isGridPosterStyle(layoutMode: "list", showTitles: false))
    }

    @Test
    func otherModeTogglesBetweenPosterGridAndList() {
        #expect(MainScreenLayoutToggle.otherMode(fromGridPoster: true) == "list")
        #expect(MainScreenLayoutToggle.otherMode(fromGridPoster: false) == "grid")
    }

    @Test
    func cardSwipeSignAllowsEitherHorizontalDirection() {
        #expect(
            MainScreenLayoutToggle.cardSwipeSign(translation: CGSize(width: -40, height: 5)) == -1
        )
        #expect(
            MainScreenLayoutToggle.cardSwipeSign(translation: CGSize(width: 40, height: 5)) == 1
        )
        #expect(
            MainScreenLayoutToggle.cardSwipeSign(translation: CGSize(width: -40, height: 50)) == nil
        )
        #expect(
            MainScreenLayoutToggle.cardSwipeSign(translation: CGSize(width: 10, height: 0)) == nil
        )
    }

    @Test
    func cardSwipeProgressUsesAbsoluteTravel() {
        let distance = MainScreenLayoutToggle.interactiveSwipeDistance
        #expect(MainScreenLayoutToggle.cardSwipeProgress(translationWidth: -distance / 2) == 0.5)
        #expect(MainScreenLayoutToggle.cardSwipeProgress(translationWidth: distance) == 1)
        #expect(MainScreenLayoutToggle.cardSwipeProgress(translationWidth: distance / 2) == 0.5)
    }

    @Test
    func shouldCommitUsesHalfwayPredictedMomentumAndCancelOnReverse() {
        let distance = MainScreenLayoutToggle.interactiveSwipeDistance
        #expect(
            MainScreenLayoutToggle.shouldCommitCardSwipe(
                progress: 0.6,
                translationWidth: -distance * 0.6,
                predictedTranslationWidth: -distance * 0.6,
                lockedSign: -1
            )
        )
        #expect(
            !MainScreenLayoutToggle.shouldCommitCardSwipe(
                progress: 0.3,
                translationWidth: -distance * 0.3,
                predictedTranslationWidth: -distance * 0.3,
                lockedSign: -1
            )
        )
        #expect(
            MainScreenLayoutToggle.shouldCommitCardSwipe(
                progress: 0.3,
                translationWidth: -distance * 0.3,
                predictedTranslationWidth: -distance,
                lockedSign: -1
            )
        )
        #expect(
            !MainScreenLayoutToggle.shouldCommitCardSwipe(
                progress: 0.4,
                translationWidth: 30,
                predictedTranslationWidth: 60,
                lockedSign: -1
            )
        )
    }

    @Test
    func toggleMatchesFloatingButton() {
        var layoutMode = "grid"
        var showTitles = false
        var art = MainScreenArtEmphasis.standard.rawValue

        MainScreenLayoutToggle.toggle(
            layoutMode: &layoutMode,
            showTitles: &showTitles,
            artEmphasis: &art
        )
        #expect(layoutMode == "list")
        #expect(showTitles)
        #expect(art == MainScreenArtEmphasis.largeArt.rawValue)

        MainScreenLayoutToggle.toggle(
            layoutMode: &layoutMode,
            showTitles: &showTitles,
            artEmphasis: &art
        )
        #expect(layoutMode == "grid")
        #expect(!showTitles)
    }

    @Test
    func gridTitlesStayOffDuringSwipeAndAfterFABFlipsToList() {
        // Settled titled grid.
        #expect(
            MainScreenLayoutToggle.gridShowsTitles(
                renderedMode: "grid",
                layoutMode: "grid",
                showTitles: true,
                isSwipeActive: false
            )
        )
        // Mid-swipe must not expand tiles.
        #expect(
            !MainScreenLayoutToggle.gridShowsTitles(
                renderedMode: "grid",
                layoutMode: "grid",
                showTitles: true,
                isSwipeActive: true
            )
        )
        // FAB already wrote list+titles while top card is still grid.
        #expect(
            !MainScreenLayoutToggle.gridShowsTitles(
                renderedMode: "grid",
                layoutMode: "list",
                showTitles: true,
                isSwipeActive: false
            )
        )
    }

    @Test
    func listTitlesShowDuringSwipeEvenBeforeStorageCommit() {
        #expect(
            MainScreenLayoutToggle.listShowsTitles(
                cardMode: "list",
                showTitles: false,
                isSwipeActive: true
            )
        )
        #expect(
            !MainScreenLayoutToggle.listShowsTitles(
                cardMode: "list",
                showTitles: false,
                isSwipeActive: false
            )
        )
        #expect(
            !MainScreenLayoutToggle.listShowsTitles(
                cardMode: "grid",
                showTitles: true,
                isSwipeActive: true
            )
        )
    }
}
