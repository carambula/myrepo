import Foundation
import Testing
@testable import PodLink

struct RecommendationAndQueueTests {
    @Test
    func autoQueueModeHasExpectedVariants() async throws {
        let modes = AutoQueueMode.allCases
        #expect(modes.contains(.gridOrder))
        #expect(modes.contains(.newestFirst))
        #expect(modes.contains(.podLinkRecommendation))
        #expect(AutoQueueMode.gridOrder.displayName == "Grid Order")
    }

    @Test
    func suggestionFeatureStorePersistsFeatures() async throws {
        let store = SuggestionFeatureStore.shared
        await store.clearAll()

        let episode = Episode(
            id: "episode-test-1",
            podcastID: "podcast-test-1",
            title: "AI Infrastructure in Healthcare",
            description: "Sparse retrieval, embeddings, and biosecurity tooling.",
            publishDate: Date(),
            duration: 1800,
            audioURL: URL(string: "https://example.com/audio.mp3")!
        )
        let podcast = Podcast(
            id: "podcast-test-1",
            title: "Frontier Builders",
            author: "Ada Lovelace",
            description: "Conversations with builders.",
            feedURL: URL(string: "https://example.com/feed.xml")!,
            categories: ["Technology", "Business"]
        )

        await store.indexEpisodeMetadata(episode: episode, podcast: podcast)
        let saved = await store.features(for: episode.id)

        #expect(saved != nil)
        #expect(saved?.episodeID == episode.id)
        #expect((saved?.features.count ?? 0) > 0)
    }

    @Test
    func recommendationFeedbackStoreRecordsEvents() async throws {
        let store = RecommendationFeedbackStore.shared
        await store.clearAll()
        await store.recordSuggestionTap("Acme Robotics", context: "test")
        await store.recordQueueOutcome(episodeID: "episode-123", completed: true, context: "test")

        let events = await store.recentEvents(limit: 10)
        #expect(events.count == 2)
        #expect(events.last?.type == .queueEpisodeFinished)
    }
}
