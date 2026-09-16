import Foundation
import Testing
@testable import PodLink

struct FollowedPodcastLibraryTests {

    private func show(
        id: String,
        feed: String,
        itunesID: String? = nil
    ) -> Podcast {
        Podcast(
            id: id,
            title: "Show",
            author: "Host",
            feedURL: URL(string: feed)!,
            itunesID: itunesID,
            isFollowed: true
        )
    }

    @Test
    func unfollowRemovesMatchingId() {
        let keep = show(id: "keep", feed: "https://a.example/feed")
        let drop = show(id: "drop", feed: "https://b.example/feed")
        let next = Podcast.applyingFollow(drop, followed: false, to: [keep, drop])
        #expect(next.map(\.id) == ["keep"])
    }

    @Test
    func unfollowRemovesSameFeedWithDifferentId() {
        let libraryShow = show(id: "library", feed: "https://feeds.example.com/show.xml")
        let sheetShow = show(id: "sheet", feed: "https://feeds.example.com/show.xml")
        let next = Podcast.applyingFollow(sheetShow, followed: false, to: [libraryShow])
        #expect(next.isEmpty)
    }

    @Test
    func unfollowRemovesSameITunesID() {
        let libraryShow = show(id: "one", feed: "https://a.example/1", itunesID: "123")
        let sheetShow = show(id: "two", feed: "https://b.example/2", itunesID: "123")
        let next = Podcast.applyingFollow(sheetShow, followed: false, to: [libraryShow])
        #expect(next.isEmpty)
    }

    @Test
    func followDoesNotDuplicateExistingFeed() {
        let existing = show(id: "library", feed: "https://feeds.example.com/show.xml/")
        let incoming = show(id: "search", feed: "https://feeds.example.com/show.xml")
        let next = Podcast.applyingFollow(incoming, followed: true, to: [existing])
        #expect(next.count == 1)
        #expect(next.first?.id == "search")
    }

    @Test
    func sameShowIgnoresTrailingSlashAndCase() {
        let lhs = show(id: "a", feed: "https://Feeds.Example.com/show.xml/")
        let rhs = show(id: "b", feed: "https://feeds.example.com/show.xml")
        #expect(Podcast.isSameFollowedShow(lhs, rhs))
    }
}
