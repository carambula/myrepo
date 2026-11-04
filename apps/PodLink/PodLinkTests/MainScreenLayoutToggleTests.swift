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
    func swipeRequiresHorizontalDominance() {
        #expect(
            MainScreenLayoutToggle.swipeDirection(translation: CGSize(width: -80, height: 10))
                == .towardList
        )
        #expect(
            MainScreenLayoutToggle.swipeDirection(translation: CGSize(width: 80, height: -8))
                == .towardGrid
        )
        #expect(MainScreenLayoutToggle.swipeDirection(translation: CGSize(width: -80, height: 70)) == nil)
        #expect(MainScreenLayoutToggle.swipeDirection(translation: CGSize(width: -40, height: 0)) == nil)
    }

    @Test
    func interactiveDirectionMatchesFingerAndStyle() {
        #expect(
            MainScreenLayoutToggle.interactiveDirection(
                translation: CGSize(width: -40, height: 5),
                fromGridPoster: true
            ) == .towardList
        )
        #expect(
            MainScreenLayoutToggle.interactiveDirection(
                translation: CGSize(width: 40, height: 5),
                fromGridPoster: true
            ) == nil
        )
        #expect(
            MainScreenLayoutToggle.interactiveDirection(
                translation: CGSize(width: 40, height: 5),
                fromGridPoster: false
            ) == .towardGrid
        )
        #expect(
            MainScreenLayoutToggle.interactiveDirection(
                translation: CGSize(width: -40, height: 5),
                fromGridPoster: false
            ) == nil
        )
    }

    @Test
    func interactiveProgressTracksHorizontalTravel() {
        let distance = MainScreenLayoutToggle.interactiveFlipDistance
        #expect(
            MainScreenLayoutToggle.interactiveProgress(
                translationWidth: -distance / 2,
                direction: .towardList
            ) == 0.5
        )
        #expect(
            MainScreenLayoutToggle.interactiveProgress(
                translationWidth: distance,
                direction: .towardGrid
            ) == 1
        )
        #expect(
            MainScreenLayoutToggle.interactiveProgress(
                translationWidth: 40,
                direction: .towardList
            ) == 0
        )
    }

    @Test
    func shouldCommitUsesHalfwayAndPredictedMomentum() {
        let distance = MainScreenLayoutToggle.interactiveFlipDistance
        #expect(
            MainScreenLayoutToggle.shouldCommit(
                progress: 0.6,
                translationWidth: -distance * 0.6,
                predictedTranslationWidth: -distance * 0.6,
                direction: .towardList
            )
        )
        #expect(
            !MainScreenLayoutToggle.shouldCommit(
                progress: 0.3,
                translationWidth: -distance * 0.3,
                predictedTranslationWidth: -distance * 0.3,
                direction: .towardList
            )
        )
        #expect(
            MainScreenLayoutToggle.shouldCommit(
                progress: 0.3,
                translationWidth: -distance * 0.3,
                predictedTranslationWidth: -distance,
                direction: .towardList
            )
        )
        #expect(
            !MainScreenLayoutToggle.shouldCommit(
                progress: 0.4,
                translationWidth: 20,
                predictedTranslationWidth: 40,
                direction: .towardList
            )
        )
    }

    @Test
    func rotationDegreesSwapAtHalfwayWithReversedDirection() {
        // Swipe left (toward list) rotates negative Y with the finger.
        #expect(MainScreenLayoutToggle.rotationDegrees(progress: 0, direction: .towardList) == 0)
        #expect(MainScreenLayoutToggle.rotationDegrees(progress: 0.25, direction: .towardList) == -45)
        #expect(MainScreenLayoutToggle.rotationDegrees(progress: 0.49, direction: .towardList) < 0)
        #expect(MainScreenLayoutToggle.rotationDegrees(progress: 0.5, direction: .towardList) == 90)
        #expect(MainScreenLayoutToggle.rotationDegrees(progress: 0.75, direction: .towardList) == 45)
        #expect(MainScreenLayoutToggle.rotationDegrees(progress: 1, direction: .towardList) == 0)

        #expect(MainScreenLayoutToggle.rotationDegrees(progress: 0.25, direction: .towardGrid) == 45)
        #expect(MainScreenLayoutToggle.rotationDegrees(progress: 0.75, direction: .towardGrid) == -45)
    }

    @Test
    func flipAnglesMatchSwipeDirection() {
        let toList = MainScreenLayoutToggle.flipAngles(from: "grid", to: "list")
        #expect(toList.outbound == -90)
        #expect(toList.inbound == 90)

        let toGrid = MainScreenLayoutToggle.flipAngles(from: "list", to: "grid")
        #expect(toGrid.outbound == 90)
        #expect(toGrid.inbound == -90)
    }

    @Test
    func showsDestinationAfterHalfway() {
        #expect(!MainScreenLayoutToggle.showsDestination(progress: 0.49))
        #expect(MainScreenLayoutToggle.showsDestination(progress: 0.5))
    }

    @Test
    func swipeLeftMovesPosterGridToList() {
        var layoutMode = "grid"
        var showTitles = false
        var art = MainScreenArtEmphasis.standard.rawValue

        MainScreenLayoutToggle.apply(
            .towardList,
            layoutMode: &layoutMode,
            showTitles: &showTitles,
            artEmphasis: &art
        )

        #expect(layoutMode == "list")
        #expect(showTitles)
        #expect(art == MainScreenArtEmphasis.largeArt.rawValue)
    }

    @Test
    func swipeRightMovesListToPosterGrid() {
        var layoutMode = "list"
        var showTitles = true
        var art = MainScreenArtEmphasis.standard.rawValue

        MainScreenLayoutToggle.apply(
            .towardGrid,
            layoutMode: &layoutMode,
            showTitles: &showTitles,
            artEmphasis: &art
        )

        #expect(layoutMode == "grid")
        #expect(!showTitles)
        #expect(art == MainScreenArtEmphasis.largeArt.rawValue)
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

        MainScreenLayoutToggle.toggle(
            layoutMode: &layoutMode,
            showTitles: &showTitles,
            artEmphasis: &art
        )
        #expect(layoutMode == "grid")
        #expect(!showTitles)
    }
}
