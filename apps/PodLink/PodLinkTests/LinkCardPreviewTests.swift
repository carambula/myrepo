import Foundation
import Testing
@testable import PodLink

struct LinkCardPreviewTests {

    @Test
    func matchesCommonServiceHosts() {
        #expect(LinkServiceBrand.matching(host: "www.youtube.com") == .youtube)
        #expect(LinkServiceBrand.matching(host: "youtu.be") == .youtube)
        #expect(LinkServiceBrand.matching(host: "m.tiktok.com") == .tiktok)
        #expect(LinkServiceBrand.matching(host: "www.instagram.com") == .instagram)
        #expect(LinkServiceBrand.matching(host: "open.spotify.com") == .spotify)
        #expect(LinkServiceBrand.matching(host: "music.apple.com") == .appleMusic)
        #expect(LinkServiceBrand.matching(host: "podcasts.apple.com") == .applePodcasts)
        #expect(LinkServiceBrand.matching(host: "example.com") == nil)
    }

    @Test
    func youtubeThumbnailUsesHQDefault() {
        let watch = URL(string: "https://www.youtube.com/watch?v=dQw4w9wgXcQ")!
        let short = URL(string: "https://youtu.be/dQw4w9wgXcQ")!
        let shorts = URL(string: "https://www.youtube.com/shorts/dQw4w9wgXcQ")!
        #expect(YouTubeLinkMedia.videoID(from: watch) == "dQw4w9wgXcQ")
        #expect(YouTubeLinkMedia.videoID(from: short) == "dQw4w9wgXcQ")
        #expect(YouTubeLinkMedia.videoID(from: shorts) == "dQw4w9wgXcQ")
        #expect(YouTubeLinkMedia.thumbnailURL(from: watch)?.absoluteString == "https://img.youtube.com/vi/dQw4w9wgXcQ/hqdefault.jpg")
    }

    @Test
    func extractorAttachesYouTubeThumbnails() {
        let notes = #"<a href="https://www.youtube.com/watch?v=dQw4w9wgXcQ">Watch</a>"#
        let links = ShowNotesMediaLinkExtractor.mediaLinks(fromShowNotes: notes)
        #expect(links.first?.imageURL?.absoluteString == "https://img.youtube.com/vi/dQw4w9wgXcQ/hqdefault.jpg")
    }

    @Test
    func treatsFaviconURLsAsIconsNotPhotographs() {
        let google = URL(string: "https://www.google.com/s2/favicons?domain=youtube.com&sz=128")!
        let ico = URL(string: "https://www.instagram.com/favicon.ico")!
        let photo = URL(string: "https://i.ytimg.com/vi/dQw4w9wgXcQ/hqdefault.jpg")!
        #expect(LinkPreviewImageResolver.looksLikeIconURL(google))
        #expect(LinkPreviewImageResolver.looksLikeIconURL(ico))
        #expect(!LinkPreviewImageResolver.looksLikeIconURL(photo))
        #expect(LinkPreviewImageResolver.photograph(from: google) == nil)
        #expect(LinkPreviewImageResolver.photograph(from: photo) == photo)
    }

    @Test
    func extractsOpenGraphPhotographAndSkipsIconMeta() {
        let page = URL(string: "https://example.com/post")!
        let html = """
        <meta property="og:image" content="https://cdn.example.com/cover.jpg">
        """
        #expect(
            LinkPreviewImageResolver.extractSocialPreviewImage(from: html, baseURL: page)?.absoluteString
                == "https://cdn.example.com/cover.jpg"
        )

        let iconHTML = """
        <meta property="og:image" content="https://example.com/favicon.ico">
        """
        #expect(LinkPreviewImageResolver.extractSocialPreviewImage(from: iconHTML, baseURL: page) == nil)
    }

    @Test
    func parsesOEmbedThumbnail() {
        let data = Data(#"{"title":"Clip","thumbnail_url":"https://cdn.tiktok.com/cover.jpg"}"#.utf8)
        #expect(LinkPreviewImageResolver.oembedThumbnail(from: data)?.absoluteString == "https://cdn.tiktok.com/cover.jpg")

        let favicon = Data(#"{"thumbnail_url":"https://www.google.com/s2/favicons?domain=tiktok.com"}"#.utf8)
        #expect(LinkPreviewImageResolver.oembedThumbnail(from: favicon) == nil)
    }

    @Test
    func buildsTikTokAndSpotifyOEmbedURLs() {
        let tiktok = URL(string: "https://www.tiktok.com/@user/video/123")!
        let spotify = URL(string: "https://open.spotify.com/track/abc")!
        #expect(LinkServiceBrand.tiktok.oembedURL(for: tiktok)?.absoluteString.contains("tiktok.com/oembed") == true)
        #expect(LinkServiceBrand.spotify.oembedURL(for: spotify)?.absoluteString.contains("spotify.com/oembed") == true)
        #expect(LinkServiceBrand.instagram.oembedURL(for: URL(string: "https://www.instagram.com/p/abc/")!) == nil)
    }
}
