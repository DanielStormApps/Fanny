//
//  LogArchiver.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation
import ZIPFoundation

/// Utility for archiving log files into a zip file.
struct LogArchiver {
    
    /// Creates a zip archive containing all log files.
    /// - Returns: URL of the created zip file, or nil on failure.
    static func createLogArchive() -> URL? {
        let fileManager: FileManager = FileManager.default
        let logDirectoryURL: URL = logDirectoryURL()
        
        guard fileManager.fileExists(atPath: logDirectoryURL.path) else {
            Log.error("Log directory does not exist")
            return nil
        }
        
        do {
            let logFiles: [URL] = try fileManager.contentsOfDirectory(at: logDirectoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                .filter { $0.pathExtension == "txt" }
            
            guard logFiles.isEmpty == false else {
                Log.error("No log files found")
                return nil
            }
            
            let archiveURL: URL = fileManager.temporaryDirectory.appendingPathComponent("logs.zip")
            
            if fileManager.fileExists(atPath: archiveURL.path) {
                try fileManager.removeItem(at: archiveURL)
            }
            
            let archive: Archive = try Archive(url: archiveURL, accessMode: .create, pathEncoding: nil)
            
            for logFileURL in logFiles {
                let fileName: String = logFileURL.lastPathComponent
                
                do {
                    try archive.addEntry(with: fileName, relativeTo: logFileURL.deletingLastPathComponent())
                }
                catch {
                    Log.error("Failed to add file to archive -> fileName: \(fileName), error: \(error.localizedDescription)")
                }
            }
            
            return archiveURL
        }
        catch {
            Log.error("Failed to create log archive -> error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// The folder `FileLogger` writes to: `~/Library/Logs/Fanny`, where macOS keeps app logs and Console lists them.
    /// - Note: Fanny is not sandboxed, so a bare folder in Application Support would be shared with every other app, and pruning old logs there could delete theirs.
    static func logDirectoryURL() -> URL {
        let libraryURL: URL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return libraryURL.appendingPathComponent("Logs", isDirectory: true).appendingPathComponent("Fanny", isDirectory: true)
    }
}
