import Foundation

// MARK: - Phase 0 ad detection: ad chapters

/// Detects ad breaks from chapter markers — e.g. ATP-style "Ad: Squarespace"
/// chapters. Pure function; the only Phase 0 detection layer.
enum ChapterAdDetector {
    /// Whole-word keywords that mark a chapter title as an ad break.
    /// A leading "ad" is handled separately as a prefix ("Ad: …", "Ad - …").
    private static let adKeywords: Set<String> = [
        "sponsor", "sponsored", "advertisement", "commercial", "promo",
    ]

    /// - Parameters:
    ///   - chapters: The episode's chapters, if the feed provides them.
    ///   - episodeDuration: Feed duration, used to classify pre/post rolls
    ///     and to bound chapters missing an end time.
    static func detect(from chapters: [Chapter]?, episodeDuration: TimeInterval) -> [AdSegment] {
        guard let chapters, !chapters.isEmpty else { return [] }
        var segments: [AdSegment] = []
        for (index, chapter) in chapters.enumerated() {
            guard isAdTitle(chapter.title) else { continue }
            let start = max(0, chapter.startTime)
            let end: TimeInterval
            if let chapterEnd = chapter.endTime, chapterEnd > start {
                end = chapterEnd
            } else if let nextStart = chapters.dropFirst(index + 1).first?.startTime,
                      nextStart > start
            {
                end = nextStart
            } else if episodeDuration > start {
                end = episodeDuration
            } else {
                continue
            }
            segments.append(AdSegment(
                startTime: start,
                endTime: end,
                kind: kindFor(start: start, end: end, episodeDuration: episodeDuration),
                confidence: 1.0,
                source: .chapters
            ))
        }
        return segments
    }

    /// Conservative title match: a leading "ad" prefix ("Ad: X", "Ad - X",
    /// "Ad break") or a whole-word keyword ("Sponsor", "Advertisement").
    /// Explicitly excludes "ad-free" style titles.
    static func isAdTitle(_ title: String) -> Bool {
        let lower = title.lowercased().trimmingCharacters(in: .whitespaces)
        guard !lower.isEmpty else { return false }
        if lower.contains("ad-free") || lower.contains("adfree") || lower.contains("ad free") {
            return false
        }
        if lower == "ad"
            || lower.hasPrefix("ad:")
            || lower.hasPrefix("ad -")
            || lower.hasPrefix("ad ")
        {
            return true
        }
        let tokens = lower
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return tokens.contains { adKeywords.contains($0) }
    }

    private static func kindFor(start: TimeInterval, end: TimeInterval, episodeDuration: TimeInterval) -> AdSegmentKind {
        if start < 60 { return .preRoll }
        if episodeDuration > 0, end >= episodeDuration - 120 { return .postRoll }
        return .midRoll
    }
}
