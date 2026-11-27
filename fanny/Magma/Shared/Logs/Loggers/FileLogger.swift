//
//  FileLogger.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A logger that writes log messages to local files on disk.
final class FileLogger: Logger {
    
    var minimumLogLevel: LogLevel? = .info
    
    private let logDirectoryURL: URL
    private let dateFormatter: DateFormatter
    private let fileManager: FileManager = FileManager.default
    private var currentLogFileURL: URL?
    private let serialQueue: DispatchQueue = DispatchQueue(label: "com.magma.filelogger.queue")
    /// Only read and written on `serialQueue`, so a message logged just before turning logs off is still written.
    private var isWritingEnabled: Bool = Storage.bool(forKey: .logsDisabled) == false
    
    /// Whether log messages are saved to disk. On until the user turns it off in Privacy Settings.
    var isEnabled: Bool {
        return serialQueue.sync { isWritingEnabled }
    }
    
    private static let maximumLogFileCount: Int = 7
    
    // MARK: - Init
    private init() {
        self.logDirectoryURL = LogArchiver.logDirectoryURL()
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.dateFormatter.calendar = Calendar(identifier: .gregorian)
        self.dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        self.dateFormatter.timeZone = TimeZone(identifier: "America/New_York")
        
        createLogDirectoryIfNeeded()
        purgeOldLogs()
        createNewLogFile()
    }
    
    static let shared: FileLogger = FileLogger()
    
    // MARK: - Logger
    func log(timestamp: String, logLevel: LogLevel, file: String, function: String, lineNumber: String, message: String) {
        guard shouldLog(logLevel: logLevel) else { return }
        let formattedMessage: String = "\(timestamp) || \(logLevel.emoji) || \(logLevel.description) || \(file) \(function)(\(lineNumber)) || \(message) ||\n"
        
        serialQueue.async { [weak self] in
            guard
                let strongSelf: FileLogger = self,
                strongSelf.isWritingEnabled,
                let logFileURL: URL = strongSelf.currentLogFileURL,
                let data: Data = formattedMessage.data(using: .utf8)
            else { return }
            
            do {
                if strongSelf.fileManager.fileExists(atPath: logFileURL.path) {
                    let fileHandle: FileHandle = try FileHandle(forWritingTo: logFileURL)
                    defer { try? fileHandle.close() }
                    try fileHandle.seekToEnd()
                    try fileHandle.write(contentsOf: data)
                }
                else {
                    try data.write(to: logFileURL)
                }
            }
            catch {
                // Not `Log`, because a write failure logged here would come back to this logger.
                print("💾 FileLogger write -> error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Enabled
    /// Logs the change while logs are still on, before turning them off and after turning them back on.
    func setEnabled(_ isEnabled: Bool) {
        guard isEnabled != self.isEnabled else { return }
        
        if isEnabled == false {
            Log.info("🔒 setLogsEnabled -> isEnabled: false")
        }
        
        serialQueue.sync {
            isWritingEnabled = isEnabled
        }
        Storage.save(isEnabled == false, forKey: .logsDisabled)
        
        if isEnabled {
            Log.info("🔒 setLogsEnabled -> isEnabled: true")
        }
    }
    
    // MARK: - Log Files
    /// Every saved log file, newest first, so the first is the one being written.
    func logFileURLs() -> [URL] {
        let keys: [URLResourceKey] = [URLResourceKey.creationDateKey, URLResourceKey.fileSizeKey]
        let files: [URL] = (try? fileManager.contentsOfDirectory(at: logDirectoryURL, includingPropertiesForKeys: keys, options: .skipsHiddenFiles)) ?? []
        return files.filter({ $0.pathExtension == "txt" }).sorted(by: { FileLogger.creationDate(of: $0) > FileLogger.creationDate(of: $1) })
    }
    
    /// Waits for queued writes first, so the size includes a line logged just before, like the one turning logs on.
    func totalByteCount() -> Int64 {
        return serialQueue.sync {
            let sizes: [Int64] = logFileURLs().map({ Int64((try? $0.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).fileSize) ?? 0) })
            return sizes.reduce(0, +)
        }
    }
    
    /// Runs after any message already queued, so nothing logged before the delete is written back afterward.
    func deleteAllLogs(completion: @escaping () -> Void) {
        serialQueue.async { [weak self] in
            guard let strongSelf: FileLogger = self else { return }
            
            for fileURL in strongSelf.logFileURLs() {
                do {
                    try strongSelf.fileManager.removeItem(at: fileURL)
                }
                catch {
                    // Not `Log`, because this runs on the queue that `Log` writes through.
                    print("💾 FileLogger deleteAllLogs -> error: \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    private static func creationDate(of fileURL: URL) -> Date {
        return (try? fileURL.resourceValues(forKeys: [URLResourceKey.creationDateKey]).creationDate) ?? Date.distantPast
    }
    
    // MARK: - Setup
    private func createLogDirectoryIfNeeded() {
        guard fileManager.fileExists(atPath: logDirectoryURL.path) == false else { return }
        
        do {
            try fileManager.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        catch {
            Log.error("💾 FileLogger createLogDirectory -> error: \(error.localizedDescription)")
        }
    }
    
    private func createNewLogFile() {
        let timestamp: String = dateFormatter.string(from: Date())
        let fileName: String = "log-\(timestamp).txt"
        let logFileURL: URL = logDirectoryURL.appendingPathComponent(fileName)
        // The file is created by its first write, so a launch with logs off leaves no empty file behind.
        currentLogFileURL = logFileURL
    }
    
    /// Leaves room for the new log file this launch creates.
    private func purgeOldLogs() {
        do {
            let logFiles: [URL] = try fileManager.contentsOfDirectory(at: logDirectoryURL, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
                .filter { $0.pathExtension == "txt" }
                .sorted { file1, file2 in
                    let date1: Date = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2: Date = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }
            
            for fileURL in logFiles.dropFirst(FileLogger.maximumLogFileCount - 1) {
                try fileManager.removeItem(at: fileURL)
            }
        }
        catch {
            Log.error("💾 FileLogger purgeOldLogs -> error: \(error.localizedDescription)")
        }
    }
}
