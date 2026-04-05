//
//  YourTubeTests.swift
//  YourTubeTests
//
//  Created by Aaron Carámbula on 3/22/26.
//

import Foundation
import Testing
@testable import YourTube

struct YourTubeTests {

    @Test func contentPolicyFiltersShortsByDurationAndHashtag() async throws {
        let normalVideo = YTVideo(
            videoID: "1",
            channelID: "A",
            title: "Long form update",
            summary: "",
            thumbnailURL: "",
            publishedAt: .now,
            durationISO8601: "PT12M1S",
            isShortCandidate: false
        )
        let hashtagShort = YTVideo(
            videoID: "2",
            channelID: "A",
            title: "New drop #Shorts",
            summary: "",
            thumbnailURL: "",
            publishedAt: .now,
            durationISO8601: "PT2M20S",
            isShortCandidate: false
        )
        let durationShort = YTVideo(
            videoID: "3",
            channelID: "A",
            title: "Quick highlight",
            summary: "",
            thumbnailURL: "",
            publishedAt: .now,
            durationISO8601: "PT0M59S",
            isShortCandidate: false
        )

        let filtered = YouTubeContentPolicy.filteredLatestVideos([normalVideo, hashtagShort, durationShort])
        #expect(filtered.count == 1)
        #expect(filtered.first?.videoID == "1")
    }

    @Test func durationParserTreatsOneMinuteThirtySecondsAsShort() async throws {
        #expect(YouTubeContentPolicy.isShortDuration("PT1M30S"))
        #expect(!YouTubeContentPolicy.isShortDuration("PT1M31S"))
    }

}
