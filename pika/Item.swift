//
//  Item.swift
//  pika
//
//  Created by Alexander Rasputin on 26.04.26.
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
