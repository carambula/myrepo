//
//  ThemePreference.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import Foundation
import SwiftData

@Model
final class ThemePreference {
    var id: UUID
    var themeID: String
    var lastModified: Date
    
    init(themeID: String) {
        self.id = UUID()
        self.themeID = themeID
        self.lastModified = Date()
    }
}
