//
//  Item.swift
//  GlassnodeWidgets
//
//  Created by Ondřej Bárta on 15/11/25.
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
