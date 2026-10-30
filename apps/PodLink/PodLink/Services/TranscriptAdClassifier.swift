import Foundation

// MARK: - Phase 2: Transcript-based ad detection (L4)

/// Detects host-read ad breaks from on-device transcripts.
///
/// Scans transcript segments for ad phrasing patterns:
/// - Sponsor introductions ("brought to you by", "thanks to our sponsor")
/// - URLs ("go to ___ dot com", "visit ___")
/// - Promo codes ("use code ___", "promo code")
/// - Calls to action ("sign up", "try it free", "get started")
///
/// This is the only layer that catches free-form host reads with no jingle.
/// Most expensive — runs only when L0-L3 are inconclusive, on transcribed
/// episodes.
enum TranscriptAdClassifier {
    /// Minimum score for a window to be considered an ad.
    private static let adThreshold = 0.5
    /// Window size for scoring (seconds of transcript).
    private static let windowSeconds: TimeInterval = 45
    /// Step between windows (overlap for boundary detection).
    private static let windowStep: TimeInterval = 15

    // MARK: - Signal patterns

    /// Strong sponsor introduction phrases (+0.4 each, max once per window).
    private static let sponsorPhrases = [
        "brought to you by",
        "sponsored by",
        "thanks to our sponsor",
        "thank you to our sponsor",
        "this episode is brought to you",
        "this show is brought to you",
        "our sponsor today",
        "today's sponsor",
    ]

    /// URL/call-to-action patterns (+0.3).
    private static let urlPhrases = [
        "go to",
        "visit",
        "head to",
        "check out",
        "dot com",
        "dot io",
        "dot co",
    ]

    /// Promo code patterns (+0.3).
    private static let promoPhrases = [
        "use code",
        "use promo code",
        "promo code",
        "discount code",
        "code ",
    ]

    /// CTA patterns (+0.2).
    private static let ctaPhrases = [
        "sign up",
        "get started",
        "try it free",
        "start your",
        "download the app",
        "limited time",
        "special offer",
    ]

    // MARK: - Classification

    /// Detected ad segments from a transcript.
    /// - Parameter transcript: Full transcript with timestamped segments.
    /// - Returns: Ad segments with `source: .transcript`, merged across windows.
    static func detect(from transcript: FullTranscript) -> [AdSegment] {
        guard let segments = transcript.segments, !segments.isEmpty else { return [] }

        // Score sliding windows
        var windows: [(start: TimeInterval, end: TimeInterval, score: Double, text: String)] = []
        let duration = segments.compactMap(\.endTime).max() ?? 0
        guard duration > 0 else { return [] }

        var windowStart: TimeInterval = 0
        while windowStart < duration {
            let windowEnd = min(windowStart + windowSeconds, duration)
            let windowText = textInRange(segments, from: windowStart, to: windowEnd)
            let score = scoreWindow(windowText)
            if score >= adThreshold {
                windows.append((windowStart, windowEnd, score, windowText))
            }
            windowStart += windowStep
        }

        // Merge overlapping windows into segments
        return mergeWindows(windows)
    }

    /// Extracts sponsor name and promo code from an ad segment's text.
    /// Used for the "ad summary + promo code" UI in the player.
    static func extractSponsorInfo(from text: String) -> (sponsor: String?, promoCode: String?) {
        let lower = text.lowercased()
        var sponsor: String?
        var promoCode: String?

        // Sponsor: "brought to you by X" or "thanks to X"
        for phrase in ["brought to you by ", "sponsored by ", "thanks to "] {
            if let range = lower.range(of: phrase) {
                let after = String(lower[range.upperBound...])
                // Take up to 4 words as the sponsor name
                let words = after.split(separator: " ").prefix(4)
                sponsor = words.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters)
                break
            }
        }

        // Promo code: "use code X" or "code X"
        if let range = lower.range(of: "code ") {
            let after = String(lower[range.upperBound...])
            if let code = after.split(separator: " ").first {
                promoCode = String(code).trimmingCharacters(in: .punctuationCharacters).uppercased()
            }
        }

        return (sponsor, promoCode)
    }

    // MARK: - Private

    private static func textInRange(
        _ segments: [TranscriptSegment],
        from start: TimeInterval,
        to end: TimeInterval
    ) -> String {
        segments
            .filter { seg in
                guard let s = seg.startTime, let e = seg.endTime else { return false }
                return e > start && s < end
            }
            .map(\.text)
            .joined(separator: " ")
    }

    private static func scoreWindow(_ text: String) -> Double {
        let lower = text.lowercased()
        guard !lower.isEmpty else { return 0 }

        var score = 0.0

        // Sponsor phrases: strong signal, count once
        if sponsorPhrases.contains(where: { lower.contains($0) }) {
            score += 0.4
        }

        // URL phrases
        let urlHits = urlPhrases.filter { lower.contains($0) }.count
        if urlHits > 0 {
            score += min(0.3, 0.15 * Double(urlHits))
        }

        // Promo phrases
        if promoPhrases.contains(where: { lower.contains($0) }) {
            score += 0.3
        }

        // CTA phrases
        let ctaHits = ctaPhrases.filter { lower.contains($0) }.count
        if ctaHits > 0 {
            score += min(0.2, 0.1 * Double(ctaHits))
        }

        return min(1.0, score)
    }

    private static func mergeWindows(
        _ windows: [(start: TimeInterval, end: TimeInterval, score: Double, text: String)]
    ) -> [AdSegment] {
        guard !windows.isEmpty else { return [] }

        var merged: [AdSegment] = []
        var currentStart = windows[0].start
        var currentEnd = windows[0].end
        var maxScore = windows[0].score
        var combinedText = windows[0].text

        for window in windows.dropFirst() {
            if window.start <= currentEnd + 5 {
                // Overlapping or adjacent: extend
                currentEnd = max(currentEnd, window.end)
                maxScore = max(maxScore, window.score)
                combinedText += " " + window.text
            } else {
                // Gap: finalize current segment
                let (sponsor, promoCode) = extractSponsorInfo(from: combinedText)
                merged.append(AdSegment(
                    startTime: currentStart,
                    endTime: currentEnd,
                    kind: kindFor(start: currentStart),
                    confidence: maxScore,
                    source: .transcript
                ))
                currentStart = window.start
                currentEnd = window.end
                maxScore = window.score
                combinedText = window.text
            }
        }

        // Final segment
        merged.append(AdSegment(
            startTime: currentStart,
            endTime: currentEnd,
            kind: kindFor(start: currentStart),
            confidence: maxScore,
            source: .transcript
        ))

        return merged
    }

    private static func kindFor(start: TimeInterval) -> AdSegmentKind {
        if start < 60 { return .preRoll }
        return .midRoll
    }
}
