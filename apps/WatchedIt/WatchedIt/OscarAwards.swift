//
//  OscarAwards.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 3/15/26.
//

import Foundation

/// Represents Oscar/Academy Award information for a movie
public struct OscarAwards: Codable, Hashable, Sendable {
    public let wins: [OscarWin]
    public let nominations: [OscarNomination]
    public let totalWins: Int
    public let totalNominations: Int
    public let rawAwardsText: String? // Original text from OMDB API
    
    public init(
        wins: [OscarWin] = [],
        nominations: [OscarNomination] = [],
        totalWins: Int = 0,
        totalNominations: Int = 0,
        rawAwardsText: String? = nil
    ) {
        self.wins = wins
        self.nominations = nominations
        self.totalWins = totalWins
        self.totalNominations = totalNominations
        self.rawAwardsText = rawAwardsText
    }
    
    /// Parse Oscar awards from OMDB awards text
    /// Example: "Won 4 Oscars. Another 130 wins & 242 nominations."
    /// Example: "Nominated for 2 Oscars. Another 17 wins & 52 nominations."
    public static func parse(from awardsText: String?) -> OscarAwards? {
        guard let text = awardsText, !text.isEmpty else { return nil }
        
        var totalWins = 0
        var totalNominations = 0
        
        // Parse wins: "Won X Oscar(s)"
        if let winsMatch = text.range(of: #"Won (\d+) Oscars?"#, options: .regularExpression) {
            let winsText = String(text[winsMatch])
            if let numberMatch = winsText.range(of: #"\d+"#, options: .regularExpression) {
                totalWins = Int(String(winsText[numberMatch])) ?? 0
            }
        }
        
        // Parse nominations: "Nominated for X Oscar(s)"
        if let nomsMatch = text.range(of: #"Nominated for (\d+) Oscars?"#, options: .regularExpression) {
            let nomsText = String(text[nomsMatch])
            if let numberMatch = nomsText.range(of: #"\d+"#, options: .regularExpression) {
                totalNominations = Int(String(nomsText[numberMatch])) ?? 0
            }
        }
        
        // Only return if we found Oscar information
        guard totalWins > 0 || totalNominations > 0 else { return nil }
        
        return OscarAwards(
            wins: [],
            nominations: [],
            totalWins: totalWins,
            totalNominations: totalNominations,
            rawAwardsText: text
        )
    }
    
    public var hasOscars: Bool {
        totalWins > 0 || totalNominations > 0
    }
    
    public var displaySummary: String {
        var parts: [String] = []
        
        if totalWins > 0 {
            let winsText = totalWins == 1 ? "1 Oscar Win" : "\(totalWins) Oscar Wins"
            parts.append(winsText)
        }
        
        if totalNominations > 0 {
            let nomsText = totalNominations == 1 ? "1 Nomination" : "\(totalNominations) Nominations"
            parts.append(nomsText)
        }
        
        return parts.joined(separator: " • ")
    }
}

/// Represents a specific Oscar win
public struct OscarWin: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let category: OscarCategory
    public let year: Int?
    public let recipient: String?
    
    public init(
        id: String = UUID().uuidString,
        category: OscarCategory,
        year: Int? = nil,
        recipient: String? = nil
    ) {
        self.id = id
        self.category = category
        self.year = year
        self.recipient = recipient
    }
}

/// Represents a specific Oscar nomination
public struct OscarNomination: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let category: OscarCategory
    public let year: Int?
    public let nominee: String?
    
    public init(
        id: String = UUID().uuidString,
        category: OscarCategory,
        year: Int? = nil,
        nominee: String? = nil
    ) {
        self.id = id
        self.category = category
        self.year = year
        self.nominee = nominee
    }
}

/// Major Oscar categories we care about
public enum OscarCategory: String, Codable, CaseIterable, Sendable {
    case bestPicture = "Best Picture"
    case bestDirector = "Best Director"
    case bestActor = "Best Actor"
    case bestActress = "Best Actress"
    case bestSupportingActor = "Best Supporting Actor"
    case bestSupportingActress = "Best Supporting Actress"
    case bestOriginalScreenplay = "Best Original Screenplay"
    case bestAdaptedScreenplay = "Best Adapted Screenplay"
    case bestCinematography = "Best Cinematography"
    case bestFilmEditing = "Best Film Editing"
    case bestVisualEffects = "Best Visual Effects"
    case bestOriginalScore = "Best Original Score"
    case bestOriginalSong = "Best Original Song"
    case bestSoundEditing = "Best Sound Editing"
    case bestSoundMixing = "Best Sound Mixing"
    case bestProductionDesign = "Best Production Design"
    case bestCostumeDesign = "Best Costume Design"
    case bestMakeup = "Best Makeup and Hairstyling"
    case bestAnimatedFeature = "Best Animated Feature"
    case bestInternationalFeature = "Best International Feature Film"
    case bestDocumentaryFeature = "Best Documentary Feature"
    case other = "Other"
    
    public var isMajorCategory: Bool {
        switch self {
        case .bestPicture, .bestDirector, .bestActor, .bestActress,
             .bestSupportingActor, .bestSupportingActress,
             .bestOriginalScreenplay, .bestAdaptedScreenplay:
            return true
        default:
            return false
        }
    }
    
    public var icon: String {
        switch self {
        case .bestPicture:
            return "film.fill"
        case .bestDirector:
            return "person.fill.viewfinder"
        case .bestActor, .bestActress, .bestSupportingActor, .bestSupportingActress:
            return "theatermasks.fill"
        case .bestOriginalScreenplay, .bestAdaptedScreenplay:
            return "doc.text.fill"
        case .bestCinematography:
            return "camera.fill"
        case .bestFilmEditing:
            return "scissors"
        case .bestVisualEffects:
            return "wand.and.stars"
        case .bestOriginalScore, .bestOriginalSong:
            return "music.note"
        case .bestSoundEditing, .bestSoundMixing:
            return "waveform"
        case .bestProductionDesign:
            return "building.2.fill"
        case .bestCostumeDesign:
            return "tshirt.fill"
        case .bestMakeup:
            return "paintbrush.fill"
        case .bestAnimatedFeature:
            return "star.fill"
        case .bestInternationalFeature:
            return "globe"
        case .bestDocumentaryFeature:
            return "doc.fill"
        case .other:
            return "star"
        }
    }
}
