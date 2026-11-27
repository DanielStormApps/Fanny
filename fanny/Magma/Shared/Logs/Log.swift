//
//  Log.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// The entry point for writing log messages at each log level.
final class Log {
    
    private init() {}
    
    static func debug(_ message: String, file: String = #file, function: String = #function, lineNumber: Int = #line) {
        LogManager.shared.log(logLevel: .debug, file: file, function: function, lineNumber: lineNumber, message: message)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, lineNumber: Int = #line) {
        LogManager.shared.log(logLevel: .info, file: file, function: function, lineNumber: lineNumber, message: message)
    }
    
    static func warn(_ message: String, file: String = #file, function: String = #function, lineNumber: Int = #line) {
        LogManager.shared.log(logLevel: .warn, file: file, function: function, lineNumber: lineNumber, message: message)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, lineNumber: Int = #line) {
        LogManager.shared.log(logLevel: .error, file: file, function: function, lineNumber: lineNumber, message: message)
    }
}
