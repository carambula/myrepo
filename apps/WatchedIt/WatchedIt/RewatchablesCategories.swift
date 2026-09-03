//
//  RewatchablesCategories.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import Foundation

public struct RewatchablesDiscussion: Codable, Hashable, Sendable {
    public var apexMountain: String? // Peak of career moment
    public var dionWaiters: String? // Heat check moment
    public var agedBest: String? // What's aged the best
    public var agedWorst: String? // What's aged the worst
    public var joeyPants: String? // Best supporting actor
    public var thatGuy: String? // Character actor
    public var unanswerableQuestions: [String] // Unanswerable questions
    public var rewatchabilityScore: Int? // 0-100 rewatchability score
    public var castingWhatIf: String? // Casting what-if
    public var apexMountainYear: Int? // Year of apex mountain
    public var dionWaitersYear: Int? // Year of dion waiters moment
    
    public init(
        apexMountain: String? = nil,
        dionWaiters: String? = nil,
        agedBest: String? = nil,
        agedWorst: String? = nil,
        joeyPants: String? = nil,
        thatGuy: String? = nil,
        unanswerableQuestions: [String] = [],
        rewatchabilityScore: Int? = nil,
        castingWhatIf: String? = nil,
        apexMountainYear: Int? = nil,
        dionWaitersYear: Int? = nil
    ) {
        self.apexMountain = apexMountain
        self.dionWaiters = dionWaiters
        self.agedBest = agedBest
        self.agedWorst = agedWorst
        self.joeyPants = joeyPants
        self.thatGuy = thatGuy
        self.unanswerableQuestions = unanswerableQuestions
        self.rewatchabilityScore = rewatchabilityScore
        self.castingWhatIf = castingWhatIf
        self.apexMountainYear = apexMountainYear
        self.dionWaitersYear = dionWaitersYear
    }
}

