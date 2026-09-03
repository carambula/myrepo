import Foundation

enum YouTubeContentPolicy {
    static func filteredLatestVideos(_ videos: [YTVideo]) -> [YTVideo] {
        videos.filter { video in
            !isShort(video)
        }
    }

    static func isShort(_ video: YTVideo) -> Bool {
        if video.title.localizedCaseInsensitiveContains("#shorts") {
            return true
        }
        guard !video.durationISO8601.isEmpty else { return false }
        return isShortDuration(video.durationISO8601)
    }

    static func isShortDuration(_ durationISO8601: String) -> Bool {
        guard !durationISO8601.isEmpty else { return false }
        return durationSeconds(from: durationISO8601) <= 90
    }

    private static func durationSeconds(from iso8601: String) -> Int {
        var total = 0
        var currentNumber = ""
        var inTimeComponent = false

        for char in iso8601 {
            if char == "T" {
                inTimeComponent = true
            } else if char.isNumber {
                currentNumber.append(char)
            } else if inTimeComponent, let value = Int(currentNumber) {
                switch char {
                case "H": total += value * 3600
                case "M": total += value * 60
                case "S": total += value
                default: break
                }
                currentNumber = ""
            }
        }
        return total
    }
}
