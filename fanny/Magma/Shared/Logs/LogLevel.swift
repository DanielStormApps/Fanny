//
//  LogLevel.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

enum LogLevel: Int {
    case debug = 1
    case info
    case warn
    case error
    
    var emoji: String {
        let value: String
        
        switch self {
        case .debug: value = "🐛"
        case .info: value = "🔮"
        case .warn: value = "⚠️⚠️"
        case .error: value = "🚫🚫🚫"
        }
        
        return value
    }
    
    var description: String {
        let value: String
        
        switch self {
        case .debug: value = "[DEBUG]"
        case .info: value = "[INFO]"
        case .warn: value = "[WARN]"
        case .error: value = "[ERROR]"
        }
        
        return value
    }
}
