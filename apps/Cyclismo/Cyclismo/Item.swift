//
//  Item.swift
//  Cyclismo
//
//  Created by Aaron Carámbula on 2/8/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
