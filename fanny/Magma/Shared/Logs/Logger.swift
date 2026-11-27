//
//  Logger.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

protocol Logger: AnyObject {
    var minimumLogLevel: LogLevel? { get set }
    func log(timestamp: String, logLevel: LogLevel, file: String, function: String, lineNumber: String, message: String)
    // MARK: - Optional
    func shouldLog(logLevel: LogLevel) -> Bool
}

extension Logger {
    
    func shouldLog(logLevel: LogLevel) -> Bool {
        guard
            let minimumLogLevel: LogLevel = minimumLogLevel,
            logLevel.rawValue >= minimumLogLevel.rawValue
        else { return false }
        return true
    }
}
