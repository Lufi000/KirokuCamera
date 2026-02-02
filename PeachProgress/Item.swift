//
//  Item.swift
//  PeachProgress
//
//  Created by yifei lu on 2026/2/2.
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
