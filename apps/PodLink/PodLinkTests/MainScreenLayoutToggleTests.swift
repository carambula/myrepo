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
    func pageIndexMapsGridAndList() {
        #expect(MainScreenLayoutToggle.pageIndex(forLayoutMode: "grid") == 0)
        #expect(MainScreenLayoutToggle.pageIndex(forLayoutMode: "list") == 1)
    }

    @Test
    func pagerAxisLockRequiresHorizontalDominance() {
        #expect(
            MainScreenLayoutToggle.pagerAxisLockTranslation(
                translation: CGSize(width: -40, height: 5)
            ) == -40
        )
        #expect(
            MainScreenLayoutToggle.pagerAxisLockTranslation(
                translation: CGSize(width: 40, height: 5)
            ) == 40
        )
        #expect(
            MainScreenLayoutToggle.pagerAxisLockTranslation(
                translation: CGSize(width: -40, height: 50)
            ) == nil
        )
        #expect(
            MainScreenLayoutToggle.pagerAxisLockTranslation(
                translation: CGSize(width: 10, height: 0)
            ) == nil
        )
    }

    @Test
    func pagerProgressAndClampStayWithinPageBounds() {
        let width: CGFloat = 390
        #expect(MainScreenLayoutToggle.pagerProgress(offset: 0, pageWidth: width) == 0)
        #expect(MainScreenLayoutToggle.pagerProgress(offset: -width / 2, pageWidth: width) == 0.5)
        #expect(MainScreenLayoutToggle.pagerProgress(offset: -width, pageWidth: width) == 1)

        #expect(
            MainScreenLayoutToggle.clampedPagerOffset(
                settledIndex: 0,
                dragTranslation: -100,
                pageWidth: width
            ) == -100
        )
        #expect(
            MainScreenLayoutToggle.clampedPagerOffset(
                settledIndex: 0,
                dragTranslation: -500,
                pageWidth: width
            ) == -width
        )
        #expect(
            MainScreenLayoutToggle.clampedPagerOffset(
                settledIndex: 1,
                dragTranslation: 100,
                pageWidth: width
            ) == -width + 100
        )
    }

    @Test
    func shouldCommitPagerSwipeUsesHalfwayAndPrediction() {
        let width: CGFloat = 390
        #expect(
            MainScreenLayoutToggle.shouldCommitPagerSwipe(
                fromIndex: 0,
                toOffset: -width * 0.6,
                predictedOffset: -width * 0.6,
                pageWidth: width
            )
        )
        #expect(
            !MainScreenLayoutToggle.shouldCommitPagerSwipe(
                fromIndex: 0,
                toOffset: -width * 0.3,
                predictedOffset: -width * 0.3,
                pageWidth: width
            )
        )
        #expect(
            MainScreenLayoutToggle.shouldCommitPagerSwipe(
                fromIndex: 0,
                toOffset: -width * 0.3,
                predictedOffset: -width,
                pageWidth: width
            )
        )
        #expect(
            MainScreenLayoutToggle.shouldCommitPagerSwipe(
                fromIndex: 1,
                toOffset: -width * 0.4,
                predictedOffset: -width * 0.4,
                pageWidth: width
            )
        )
    }

    @Test
    func chromeBlurBlendsBetweenPageScrollOffsets() {
        #expect(
            MainScreenLayoutToggle.scrollBlurProgress(scrollOffset: 0, blurDistance: 80) == 0
        )
        #expect(
            MainScreenLayoutToggle.scrollBlurProgress(scrollOffset: 40, blurDistance: 80) == 0.5
        )
        #expect(
            MainScreenLayoutToggle.blendedChromeBlurProgress(
                gridScrollOffset: 0,
                listScrollOffset: 80,
                pagerProgress: 0.5,
                blurDistance: 80
            ) == 0.5
        )
        #expect(
            MainScreenLayoutToggle.blendedChromeBlurProgress(
                gridScrollOffset: 0,
                listScrollOffset: 80,
                pagerProgress: 1,
                blurDistance: 80
            ) == 1
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
    func gridTitlesStayOffDuringPagerSwipe() {
        #expect(
            MainScreenLayoutToggle.gridShowsTitles(
                layoutMode: "grid",
                showTitles: true,
                isPagerActive: false
            )
        )
        #expect(
            !MainScreenLayoutToggle.gridShowsTitles(
                layoutMode: "grid",
                showTitles: true,
                isPagerActive: true
            )
        )
        #expect(MainScreenLayoutToggle.listShowsTitles(isListPage: true))
        #expect(!MainScreenLayoutToggle.listShowsTitles(isListPage: false))
    }
}
