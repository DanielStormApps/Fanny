//
//  LogsTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/26/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests that the Logs switch logs turning off before logging stops, and turning on once logging is back.
final class LogsTests: XCTestCase {
    
    func testTurningLogsOffAndOnLogsBothChanges() throws {
        let wasEnabled: Bool = FileLogger.shared.isEnabled
        defer { FileLogger.shared.setEnabled(wasEnabled) }
        
        FileLogger.shared.setEnabled(true)
        let marker: String = UUID().uuidString
        
        FileLogger.shared.setEnabled(false)
        XCTAssertFalse(FileLogger.shared.isEnabled)
        XCTAssertTrue(Storage.bool(forKey: .logsDisabled))
        Log.info("while off \(marker)")
        
        FileLogger.shared.setEnabled(true)
        XCTAssertTrue(FileLogger.shared.isEnabled)
        XCTAssertFalse(Storage.bool(forKey: .logsDisabled))
        Log.info("while on \(marker)")
        
        // Reading `isEnabled` waits for every queued write, so the file is complete.
        _ = FileLogger.shared.isEnabled
        let logFileURL: URL = try XCTUnwrap(FileLogger.shared.logFileURLs().first)
        let text: String = try String(contentsOf: logFileURL, encoding: String.Encoding.utf8)
        
        let offRange: Range<String.Index> = try XCTUnwrap(text.range(of: "🔒 setLogsEnabled -> isEnabled: false", options: .backwards))
        let onRange: Range<String.Index> = try XCTUnwrap(text.range(of: "🔒 setLogsEnabled -> isEnabled: true", options: .backwards))
        let whileOnRange: Range<String.Index> = try XCTUnwrap(text.range(of: "while on \(marker)"))
        XCTAssertFalse(text.contains("while off \(marker)"))
        XCTAssertLessThan(offRange.lowerBound, onRange.lowerBound)
        XCTAssertLessThan(onRange.lowerBound, whileOnRange.lowerBound)
    }
}
