import Foundation

enum EpisodeQueueBuilder {
    /// Picks the newest unfinished episode. `episodes` should already be newest-first
    /// (as from `EpisodeArchive.merge` / live RSS). Merges playback state one episode at a
    /// time and stops at the first match so large archives do not thrash UserDefaults.
    static func latestUnfinished(in episodes: [Episode], excluding excludedID: String? = nil) -> Episode? {
        let newestFirst = episodes.sorted { $0.publishDate > $1.publishDate }
        for episode in newestFirst {
            let merged = EpisodePlaybackStore.merge(episode)
            if let excludedID, merged.id == excludedID {
                continue
            }
            if !merged.isEffectivelyFinished {
                return merged
            }
        }
        return nil
    }
}
