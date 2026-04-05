#!/usr/bin/env swift

// Test Oscar awards parsing

import Foundation

// Copy of OscarAwards struct for testing
struct OscarAwards: Codable, Hashable {
    let totalWins: Int
    let totalNominations: Int
    let rawAwardsText: String?
    
    static func parse(from awardsText: String?) -> OscarAwards? {
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
            totalWins: totalWins,
            totalNominations: totalNominations,
            rawAwardsText: text
        )
    }
    
    var hasOscars: Bool {
        totalWins > 0 || totalNominations > 0
    }
}

// Test cases
let testCases = [
    "Won 4 Oscars. Another 130 wins & 242 nominations.",
    "Nominated for 2 Oscars. Another 17 wins & 52 nominations.",
    "Won 11 Oscars. Another 140 wins & 100 nominations.",
    "Nominated for 10 Oscars. Another 50 wins & 100 nominations.",
    "Won 1 Oscar. Another 20 wins & 30 nominations.",
    "Nominated for 1 Oscar. Another 10 wins & 15 nominations.",
    "12 wins & 45 nominations.",
    "",
    nil
]

print("🧪 Testing Oscar Awards Parsing\n")

for (index, testCase) in testCases.enumerated() {
    print("Test \(index + 1): \"\(testCase ?? "nil")\"")
    
    if let awards = OscarAwards.parse(from: testCase) {
        print("  ✅ Parsed successfully:")
        print("     - Total Wins: \(awards.totalWins)")
        print("     - Total Nominations: \(awards.totalNominations)")
        print("     - Has Oscars: \(awards.hasOscars)")
    } else {
        print("  ⚠️  No Oscar information found")
    }
    print("")
}

print("✅ All parsing tests completed!")
