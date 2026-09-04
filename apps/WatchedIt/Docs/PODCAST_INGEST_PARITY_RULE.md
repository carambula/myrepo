# Podcast Ingest Parity Rule

This project has three podcast-ingest surfaces that must stay behaviorally aligned:

- Web admin: `bootstrap_web/server.js`
- iOS app: `WatchedIt/PodcastEpisodeIntakeService.swift`
- tvOS app: `WatchedIt/PodcastEpisodeIntakeService.swift` (shared through `WatchedItCore`)

## Rule

When updating podcast title reliability, candidate filtering, or TMDB query shaping in web admin, apply the same change in `PodcastEpisodeIntakeService.swift` in the same PR.

## Minimum parity checklist

1. `cleanPodcastTitle` logic is equivalent between web and Swift.
2. TMDB query/year extraction logic is equivalent (`buildTmdbSearchInput` in web, `buildTMDBSearchInput` in Swift).
3. Noise filtering rules are equivalent (`shouldSkipPodcastNoise`).
4. Tests are updated in `WatchedItTests/WatchedItTests.swift` for changed behavior.
5. TMDB `/movie/{id}/watch/providers` (US region) enrichment stays aligned between web and app: bootstrap `fetchStreamingServices` / `mapStreamingProviders` in `bootstrap_web/server.js` and `MovieDataService.getStreamingProviders` in `PodcastEpisodeIntakeService.swift`'s `enrichCandidate`.

## Why

iOS and tvOS share one core service, so keeping that service in lockstep with web admin prevents ingestion drift, duplicate handling differences, and inconsistent "new episode" detection across platforms.
