//
//  Item.swift
//  YourTube
//
//  Created by Aaron Carámbula on 3/22/26.
//

import Foundation
import SwiftData

@Model
final class YTChannel {
    var channelID: String = ""
    var title: String = ""
    var summary: String = ""
    var thumbnailURL: String = ""
    var uploadsPlaylistID: String = ""
    var isUserSubscribed: Bool = false
    var lastSyncedAt: Date = Date.now

    init(
        channelID: String,
        title: String,
        summary: String = "",
        thumbnailURL: String = "",
        uploadsPlaylistID: String = "",
        isUserSubscribed: Bool = false,
        lastSyncedAt: Date = Date.now
    ) {
        self.channelID = channelID
        self.title = title
        self.summary = summary
        self.thumbnailURL = thumbnailURL
        self.uploadsPlaylistID = uploadsPlaylistID
        self.isUserSubscribed = isUserSubscribed
        self.lastSyncedAt = lastSyncedAt
    }
}

@Model
final class YTVideo {
    var videoID: String = ""
    var channelID: String = ""
    var title: String = ""
    var summary: String = ""
    var thumbnailURL: String = ""
    var publishedAt: Date = Date.now
    var durationISO8601: String = ""
    var isShortCandidate: Bool = false
    var lastSyncedAt: Date = Date.now

    init(
        videoID: String,
        channelID: String,
        title: String,
        summary: String = "",
        thumbnailURL: String = "",
        publishedAt: Date = Date.now,
        durationISO8601: String = "",
        isShortCandidate: Bool = false,
        lastSyncedAt: Date = Date.now
    ) {
        self.videoID = videoID
        self.channelID = channelID
        self.title = title
        self.summary = summary
        self.thumbnailURL = thumbnailURL
        self.publishedAt = publishedAt
        self.durationISO8601 = durationISO8601
        self.isShortCandidate = isShortCandidate
        self.lastSyncedAt = lastSyncedAt
    }
}

@Model
final class UserSubscription {
    var channelID: String = ""
    var addedAt: Date = Date.now

    init(channelID: String, addedAt: Date = Date.now) {
        self.channelID = channelID
        self.addedAt = addedAt
    }
}

@Model
final class WatchState {
    var videoID: String = ""
    var progressSeconds: Double = 0
    var isCompleted: Bool = false
    var lastWatchedAt: Date = Date.now

    init(
        videoID: String,
        progressSeconds: Double = 0,
        isCompleted: Bool = false,
        lastWatchedAt: Date = Date.now
    ) {
        self.videoID = videoID
        self.progressSeconds = progressSeconds
        self.isCompleted = isCompleted
        self.lastWatchedAt = lastWatchedAt
    }
}

@Model
final class ThemePreference {
    var key: String = "appTheme"
    var selectedThemeID: String = "midnight"
    var searchPlacementRawValue: String = NavigationSearchPlacement.topLeading.rawValue
    var updatedAt: Date = Date.now

    init(
        key: String = "appTheme",
        selectedThemeID: String = "midnight",
        searchPlacementRawValue: String = NavigationSearchPlacement.topLeading.rawValue,
        updatedAt: Date = Date.now
    ) {
        self.key = key
        self.selectedThemeID = selectedThemeID
        self.searchPlacementRawValue = searchPlacementRawValue
        self.updatedAt = updatedAt
    }
}

@Model
final class SearchHistoryEntry {
    var query: String = ""
    var createdAt: Date = Date.now

    init(query: String, createdAt: Date = Date.now) {
        self.query = query
        self.createdAt = createdAt
    }
}

@Model
final class ChannelOrderPreference {
    var key: String = "channelOrder"
    var orderedChannelIDsCSV: String = ""
    var updatedAt: Date = Date.now

    init(
        key: String = "channelOrder",
        orderedChannelIDsCSV: String = "",
        updatedAt: Date = Date.now
    ) {
        self.key = key
        self.orderedChannelIDsCSV = orderedChannelIDsCSV
        self.updatedAt = updatedAt
    }
}
