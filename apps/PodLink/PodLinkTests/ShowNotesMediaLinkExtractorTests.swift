import Foundation
import Testing
@testable import PodLink

struct ShowNotesMediaLinkExtractorTests {

    @Test
    func extractsEveryHTMLHref() {
        let notes = """
        Links: <a href="https://www.imdb.com/title/tt0073195/">Jaws</a>
        and <a href="https://www.youtube.com/watch?v=abc123">Watch</a>
        """
        let links = ShowNotesMediaLinkExtractor.mediaLinks(fromShowNotes: notes)
        let urls = Set(links.map { $0.destinationURL.absoluteString })
        #expect(urls.contains("https://www.imdb.com/title/tt0073195/"))
        #expect(urls.contains("https://www.youtube.com/watch?v=abc123"))
        #expect(links.contains(where: { $0.title == "Jaws" && $0.type == .movie }))
        #expect(links.contains(where: { $0.title == "Watch" && $0.type == .youtubeVideo }))
    }

    @Test
    func keepsLinksWithShortOrEmptyAnchorText() {
        let notes = #"<a href="https://example.com/x">x</a> <a href="https://news.example.com/story"></a>"#
        let links = ShowNotesMediaLinkExtractor.mediaLinks(fromShowNotes: notes)
        let hosts = Set(links.compactMap { $0.destinationURL.host })
        #expect(hosts.contains("example.com"))
        #expect(hosts.contains("news.example.com"))
        #expect(links.count == 2)
    }

    @Test
    func extractsBareURLsFromPlainNotes() {
        let notes = "Listen extras at https://foo.example.com/bar and www.youtube.com/watch?v=zz9"
        let links = ShowNotesMediaLinkExtractor.mediaLinks(fromShowNotes: notes)
        #expect(links.contains(where: { $0.destinationURL.host == "foo.example.com" }))
        #expect(links.contains(where: {
            ($0.destinationURL.host ?? "").contains("youtube.com") && $0.destinationURL.absoluteString.contains("zz9")
        }))
    }

    @Test
    func extractsMarkdownLinks() {
        let notes = "See [Trailer](https://youtu.be/deadbeef) and [Book](https://example.com/book)"
        let links = ShowNotesMediaLinkExtractor.mediaLinks(fromShowNotes: notes)
        #expect(links.contains(where: { $0.title == "Trailer" && $0.destinationURL.host == "youtu.be" }))
        #expect(links.contains(where: { $0.title == "Book" && $0.destinationURL.host == "example.com" }))
    }

    @Test
    func dedupesTheSameURLFromHrefAndBareText() {
        let notes = """
        <a href="https://example.com/same">Same</a>
        Also https://example.com/same
        """
        let links = ShowNotesMediaLinkExtractor.mediaLinks(fromShowNotes: notes)
        #expect(links.count == 1)
        #expect(links.first?.title == "Same")
    }

    @Test
    func keepsDistinctURLsThatShareATitle() {
        let notes = """
        <a href="https://www.youtube.com/watch?v=one">Watch</a>
        <a href="https://www.youtube.com/watch?v=two">Watch</a>
        """
        let links = ShowNotesMediaLinkExtractor.mediaLinks(fromShowNotes: notes)
        #expect(links.count == 2)
        let ids = Set(links.map { $0.destinationURL.query })
        #expect(ids.contains("v=one"))
        #expect(ids.contains("v=two"))
    }

    @Test
    func decodesHTMLEntitiesInHrefs() {
        let notes = #"<a href="https://example.com/path?a=1&amp;b=2">Query</a>"#
        let links = ShowNotesMediaLinkExtractor.mediaLinks(fromShowNotes: notes)
        #expect(links.contains(where: {
            $0.destinationURL.absoluteString.contains("a=1") && $0.destinationURL.absoluteString.contains("b=2")
        }))
    }

    @Test
    func skipsNonWebSchemes() {
        let notes = #"Email <a href="mailto:hi@example.com">hi</a> or tel:555-0100"#
        let links = ShowNotesMediaLinkExtractor.mediaLinks(fromShowNotes: notes)
        #expect(links.isEmpty)
    }

    @Test
    func classifiesKnownHostsAndFallsBackToWebsite() {
        let notes = """
        <a href="https://apps.apple.com/app/id1">App</a>
        <a href="https://open.spotify.com/track/1">Song</a>
        <a href="https://obscure-blog.example/post">Post</a>
        """
        let links = ShowNotesMediaLinkExtractor.mediaLinks(fromShowNotes: notes)
        #expect(links.contains(where: { $0.type == .app }))
        #expect(links.contains(where: { $0.type == .song }))
        #expect(links.contains(where: { $0.type == .website && $0.title == "Post" }))
    }

    @Test
    func extractMediaLinksKeepsEveryShowNoteURL() async {
        let episode = Episode(
            podcastID: "test-show",
            title: "Weekly recap without quoted titles",
            description: """
            <a href="https://www.imdb.com/title/tt0073195/">Jaws</a>
            Extra https://example.com/notes
            <a href="https://www.youtube.com/watch?v=one">Watch</a>
            <a href="https://www.youtube.com/watch?v=two">Watch</a>
            """,
            audioURL: URL(string: "https://example.com/ep.mp3")!,
            transcript: ""
        )
        let links = await MediaLinkingService.shared.extractMediaLinks(from: episode)
        let destinations = links.map(\.destinationURL.absoluteString)
        #expect(destinations.contains(where: { $0.contains("imdb.com/title/tt0073195") }))
        #expect(destinations.contains(where: { $0.contains("example.com/notes") }))
        #expect(destinations.contains(where: { $0.contains("v=one") }))
        #expect(destinations.contains(where: { $0.contains("v=two") }))
    }

    @Test
    func canonicalURLKeyLowercasesHostAndDropsTrailingSlash() {
        let mixed = URL(string: "HTTPS://WWW.Example.COM/Path/")!
        let plain = URL(string: "https://www.example.com/Path")!
        #expect(ShowNotesMediaLinkExtractor.canonicalURLKey(mixed) == ShowNotesMediaLinkExtractor.canonicalURLKey(plain))
    }
}
