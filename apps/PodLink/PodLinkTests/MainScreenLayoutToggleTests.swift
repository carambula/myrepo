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
    func swipeDoesNotBounceWhenAlreadyOnTarget() {
        var layoutMode = "list"
        var showTitles = true
        var art = MainScreenArtEmphasis.largeArt.rawValue

        MainScreenLayoutToggle.apply(
            .towardList,
            layoutMode: &layoutMode,
            showTitles: &showTitles,
            artEmphasis: &art
        )
        #expect(layoutMode == "list")

        layoutMode = "grid"
        showTitles = false
        MainScreenLayoutToggle.apply(
            .towardGrid,
            layoutMode: &layoutMode,
            showTitles: &showTitles,
            artEmphasis: &art
        )
        #expect(layoutMode == "grid")
        #expect(!showTitles)
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

    @Test
    func flipAnglesMatchSwipeDirection() {
        let toList = MainScreenLayoutToggle.flipAngles(from: "grid", to: "list")
        #expect(toList.outbound == 90)
        #expect(toList.inbound == -90)

        let toGrid = MainScreenLayoutToggle.flipAngles(from: "list", to: "grid")
        #expect(toGrid.outbound == -90)
        #expect(toGrid.inbound == 90)

        #expect(MainScreenLayoutToggle.flipAngles(for: .towardList).outbound == 90)
        #expect(MainScreenLayoutToggle.flipAngles(for: .towardGrid).outbound == -90)
    }
}
