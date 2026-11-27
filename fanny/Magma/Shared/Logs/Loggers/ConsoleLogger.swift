//
//  ConsoleLogger.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A logger that prints log messages to the console.
final class ConsoleLogger: Logger {
    
    var minimumLogLevel: LogLevel?
    
    func log(timestamp: String, logLevel: LogLevel, file: String, function: String, lineNumber: String, message: String) {
        guard shouldLog(logLevel: logLevel) else { return }
        print("\(timestamp) || \(logLevel.emoji) || \(logLevel.description) || \(file) \(function)(\(lineNumber)) || \(message) ||")
    }
}
