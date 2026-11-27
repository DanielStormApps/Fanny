//
//  CrashlyticsLogger.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation
import FirebaseCrashlytics

/// A logger that adds log messages to the next Crashlytics report.
final class CrashlyticsLogger: Logger {
    
    var minimumLogLevel: LogLevel? = .info
    
    func log(timestamp: String, logLevel: LogLevel, file: String, function: String, lineNumber: String, message: String) {
        guard shouldLog(logLevel: logLevel) else { return }
        Crashlytics.crashlytics().log("\(timestamp) || \(logLevel.emoji) || \(logLevel.description) || \(file) \(function)(\(lineNumber)) || \(message) ||")
    }
}
