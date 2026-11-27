//
//  ReadingsSnapshotTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the reading models shared with the widget.
final class ReadingsSnapshotTests: XCTestCase {
    
    func testFanAtRestReadsAsStopped() {
        let fan: FanReading = FanReading(id: 0, currentRPM: 0.0, minimumRPM: 1350.0, maximumRPM: 5349.0, targetRPM: 0.0)
        XCTAssertTrue(fan.isStopped)
    }
    
    func testSpinningFanIsNotStopped() {
        let fan: FanReading = FanReading(id: 1, currentRPM: 1522.0, minimumRPM: 1522.0, maximumRPM: 5777.0, targetRPM: 1522.0)
        XCTAssertFalse(fan.isStopped)
    }
    
    func testFanWithoutAMaximumIsNotStopped() {
        XCTAssertFalse(FanReading(id: 0, currentRPM: 0.0, minimumRPM: nil, maximumRPM: nil, targetRPM: nil).isStopped)
        XCTAssertFalse(FanReading(id: 0, currentRPM: 0.0, minimumRPM: 0.0, maximumRPM: 0.0, targetRPM: 0.0).isStopped)
    }
    
    func testFanlessSnapshotHasNoFans() {
        let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: Date(), fanStatus: .noFans, cpuTemperature: TemperatureReading(celsius: 42.5))
        XCTAssertEqual(snapshot.fanStatus, .noFans)
        XCTAssertTrue(snapshot.fans.isEmpty)
        XCTAssertNil(snapshot.gpuTemperature)
    }
    
    func testUnavailableSnapshotHasNoReadings() {
        let date: Date = Date(timeIntervalSinceReferenceDate: 800000000.0)
        let snapshot: ReadingsSnapshot = ReadingsSnapshot.unavailable(at: date)
        XCTAssertEqual(snapshot.capturedDate, date)
        XCTAssertEqual(snapshot.fanStatus, .unavailable)
        XCTAssertTrue(snapshot.fans.isEmpty)
        XCTAssertNil(snapshot.cpuTemperature)
        XCTAssertNil(snapshot.gpuTemperature)
    }
    
    func testSnapshotRoundTrips() throws {
        let fans: [FanReading] = [FanReading(id: 0, currentRPM: 0.0, minimumRPM: 1350.0, maximumRPM: 5349.0, targetRPM: 0.0),
                                  FanReading(id: 1, currentRPM: 1522.0, minimumRPM: 1522.0, maximumRPM: 5777.0, targetRPM: nil),]
        let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: Date(timeIntervalSinceReferenceDate: 800000000.0),
                                                          fanStatus: .fans,
                                                          fans: fans,
                                                          cpuTemperature: TemperatureReading(celsius: 45.2),
                                                          gpuTemperature: TemperatureReading(celsius: 40.1))
        let data: Data = try JSONEncoder().encode(snapshot)
        XCTAssertEqual(try JSONDecoder().decode(ReadingsSnapshot.self, from: data), snapshot)
    }
    
    func testTemperatureConvertsToEachUnit() {
        let temperature: TemperatureReading = TemperatureReading(celsius: 45.0)
        XCTAssertEqual(temperature.value(in: .celsius), 45.0, accuracy: 0.0001)
        XCTAssertEqual(temperature.value(in: .fahrenheit), 113.0, accuracy: 0.0001)
        XCTAssertEqual(temperature.value(in: .kelvin), 318.15, accuracy: 0.0001)
    }
}
