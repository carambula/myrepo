import Foundation
import Testing
@testable import PodLink

struct EpisodeArchiveTests {
    @Test
    func unionsTruncatedCatalogWithLiveArchive() {
        let catalog = [
            episode(id: "ep-new", title: "Fargo", date: date(2025, 4, 1)),
            episode(id: "ep-overlap", title: "Heat", date: date(2025, 3, 1))
        ]
        let live = [
            episode(id: "ep-overlap", title: "Heat (live)", date: date(2025, 3, 1)),
            episode(
                id: "ep-rocky",
                title: "‘Rocky’ With Bill Simmons, Chris Ryan, and Van Lathan",
                date: date(2018, 4, 17),
                audio: "https://example.com/rocky.mp3"
            )
        ]

        let merged = EpisodeArchive.merge(catalog, live)
        #expect(merged.count == 3)
        #expect(merged[0].title == "Fargo")
        #expect(merged[1].title == "Heat")
        #expect(merged[2].id == "ep-rocky")
    }

    @Test
    func dedupesByAudioURLWhenGuidsDiffer() {
        let catalog = episode(id: "catalog-guid", title: "Rocky", date: date(2018, 4, 17), audio: "https://cdn.example.com/rocky.mp3")
        let live = episode(id: "live-guid", title: "Rocky (live)", date: date(2018, 4, 17), audio: "https://cdn.example.com/rocky.mp3")
        let merged = EpisodeArchive.merge([catalog], [live])
        #expect(merged.count == 1)
        #expect(merged[0].title == "Rocky")
    }

    @Test
    func prefersNewerPublishDate() {
        let older = episode(id: "a", title: "Older", date: date(2018, 1, 1))
        let newer = episode(id: "b", title: "Newer", date: date(2025, 5, 1))
        let merged = EpisodeArchive.merge([older], [newer])
        #expect(merged.map(\.title) == ["Newer", "Older"])
    }

    private func episode(
        id: String,
        title: String,
        date: Date,
        audio: String = "https://example.com/audio.mp3"
    ) -> Episode {
        Episode(
            id: id,
            podcastID: "rewatchables",
            title: title,
            publishDate: date,
            audioURL: URL(string: audio)!
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
