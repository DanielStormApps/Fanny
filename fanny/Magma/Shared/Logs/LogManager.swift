//
//  LogManager.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A shared instance class that sends each log message to every registered logger.
final class LogManager {
    
    private static let dateFormatter: DateFormatter = {
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS Z"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        return dateFormatter
    }()
    
    private var loggers: [Logger] = []
    
    private var minimumLogLevel: LogLevel {
        #if DEBUG
            return .debug
        #else
            return .info
        #endif
    }
    
    // MARK: - Init
    private init() {}
    static let shared: LogManager = LogManager()
    
    func add(logger: Logger) {
        logger.minimumLogLevel = logger.minimumLogLevel == nil
            ? minimumLogLevel
            : logger.minimumLogLevel
        loggers.append(logger)
    }
    
    func log(logLevel: LogLevel, file: String = #file, function: String = #function, lineNumber: Int = #line, message: String) {
        let timestamp: String = timestamp()
        let file: String = file.lastPathComponent
        let lineNumber: String = String(lineNumber)
        
        for logger in loggers {
            logger.log(timestamp: timestamp, logLevel: logLevel, file: file, function: function, lineNumber: lineNumber, message: message)
        }
    }
    
    private func timestamp() -> String {
        return LogManager.dateFormatter.string(from: Date())
    }
}
