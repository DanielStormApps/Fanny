//
//  SensorMonitorTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the monitor's change detection, snapshot saving, and refresh timing.
final class SensorMonitorTests: XCTestCase {
    
    private let date: Date = Date(timeIntervalSinceReferenceDate: 800000000.0)
    
    // MARK: - Change Detection
    func testFirstSnapshotIsAChange() {
        XCTAssertTrue(SensorMonitor.isVisibleChange(from: nil, to: makeSnapshot(), unit: .celsius))
    }
    
    func testSameSnapshotIsNotAChange() {
        XCTAssertFalse(SensorMonitor.isVisibleChange(from: makeSnapshot(), to: makeSnapshot(), unit: .celsius))
    }
    
    func testNewDateAloneIsNotAChange() {
        let laterSnapshot: ReadingsSnapshot = makeSnapshot(capturedDate: date.addingTimeInterval(3.0))
        XCTAssertFalse(SensorMonitor.isVisibleChange(from: makeSnapshot(), to: laterSnapshot, unit: .celsius))
    }
    
    func testTemperatureChangeBelowOneDecimalIsNotAChange() {
        let previousSnapshot: ReadingsSnapshot = makeSnapshot(cpuCelsius: 45.21)
        let snapshot: ReadingsSnapshot = makeSnapshot(cpuCelsius: 45.23)
        XCTAssertFalse(SensorMonitor.isVisibleChange(from: previousSnapshot, to: snapshot, unit: .celsius))
    }
    
    func testTemperatureChangeAtOneDecimalIsAChange() {
        let previousSnapshot: ReadingsSnapshot = makeSnapshot(cpuCelsius: 45.2)
        let snapshot: ReadingsSnapshot = makeSnapshot(cpuCelsius: 45.3)
        XCTAssertTrue(SensorMonitor.isVisibleChange(from: previousSnapshot, to: snapshot, unit: .celsius))
    }
    
    func testChangeIsJudgedInTheChosenUnit() {
        // 45.02 and 45.04 °C both show 45.0 °C, but 113.0 and 113.1 °F.
        let previousSnapshot: ReadingsSnapshot = makeSnapshot(cpuCelsius: 45.02)
        let snapshot: ReadingsSnapshot = makeSnapshot(cpuCelsius: 45.04)
        XCTAssertFalse(SensorMonitor.isVisibleChange(from: previousSnapshot, to: snapshot, unit: .celsius))
        XCTAssertTrue(SensorMonitor.isVisibleChange(from: previousSnapshot, to: snapshot, unit: .fahrenheit))
    }
    
    func testHiddenTemperatureIsAChange() {
        let snapshot: ReadingsSnapshot = makeSnapshot(gpuCelsius: nil)
        XCTAssertTrue(SensorMonitor.isVisibleChange(from: makeSnapshot(), to: snapshot, unit: .celsius))
    }
    
    func testFanSpeedBelowOneRPMIsNotAChange() {
        let previousSnapshot: ReadingsSnapshot = makeSnapshot(fanRPM: 1350.2)
        let snapshot: ReadingsSnapshot = makeSnapshot(fanRPM: 1350.4)
        XCTAssertFalse(SensorMonitor.isVisibleChange(from: previousSnapshot, to: snapshot, unit: .celsius))
    }
    
    func testFanSpeedChangeIsAChange() {
        let previousSnapshot: ReadingsSnapshot = makeSnapshot(fanRPM: 1350.0)
        let snapshot: ReadingsSnapshot = makeSnapshot(fanRPM: 1362.0)
        XCTAssertTrue(SensorMonitor.isVisibleChange(from: previousSnapshot, to: snapshot, unit: .celsius))
    }
    
    func testFanStoppingIsAChange() {
        let previousSnapshot: ReadingsSnapshot = makeSnapshot(fanRPM: 1.2)
        let snapshot: ReadingsSnapshot = makeSnapshot(fanRPM: 0.8)
        XCTAssertTrue(SensorMonitor.isVisibleChange(from: previousSnapshot, to: snapshot, unit: .celsius))
    }
    
    func testFanStatusChangeIsAChange() {
        XCTAssertTrue(SensorMonitor.isVisibleChange(from: makeSnapshot(), to: ReadingsSnapshot.unavailable(at: date), unit: .celsius))
    }
    
    // MARK: - Saving
    func testFirstSnapshotIsSaved() {
        XCTAssertTrue(SensorMonitor.shouldSaveSnapshot(isVisibleChange: false, lastSavedDate: nil, date: date))
    }
    
    func testChangedSnapshotIsSaved() {
        XCTAssertTrue(SensorMonitor.shouldSaveSnapshot(isVisibleChange: true, lastSavedDate: date, date: date.addingTimeInterval(1.0)))
    }
    
    func testUnchangedSnapshotIsSavedOnlyEveryMinute() {
        XCTAssertFalse(SensorMonitor.shouldSaveSnapshot(isVisibleChange: false, lastSavedDate: date, date: date.addingTimeInterval(59.0)))
        XCTAssertTrue(SensorMonitor.shouldSaveSnapshot(isVisibleChange: false, lastSavedDate: date, date: date.addingTimeInterval(60.0)))
    }
    
    func testClockMovingBackwardSaves() {
        XCTAssertTrue(SensorMonitor.shouldSaveSnapshot(isVisibleChange: false, lastSavedDate: date, date: date.addingTimeInterval(-5.0)))
    }
    
    // MARK: - Timing
    func testOpenMenuRefreshesEverySecond() {
        XCTAssertEqual(SensorMonitor.refreshTimeInterval(settingsTimeInterval: 3.0, isMenuOpen: false), 3.0)
        XCTAssertEqual(SensorMonitor.refreshTimeInterval(settingsTimeInterval: 3.0, isMenuOpen: true), 1.0)
        XCTAssertEqual(SensorMonitor.refreshTimeInterval(settingsTimeInterval: 60.0, isMenuOpen: true), 1.0)
        XCTAssertEqual(SensorMonitor.refreshTimeInterval(settingsTimeInterval: 1.0, isMenuOpen: true), 1.0)
    }
    
    func testSensorSettingsNeedANewRead() {
        let settings: FannySettings = FannySettings(locale: Locale(identifier: "en_GB"))
        var updatedSettings: FannySettings = settings
        XCTAssertTrue(SensorMonitor.changesReadings(from: nil, to: settings))
        
        updatedSettings.temperatureUnit = .kelvin
        updatedSettings.menuBarLayout.setVisible(true, kind: .cpu)
        updatedSettings.refreshTimeInterval = 10.0
        XCTAssertFalse(SensorMonitor.changesReadings(from: settings, to: updatedSettings))
        
        updatedSettings.showsGPUTemperature = false
        XCTAssertTrue(SensorMonitor.changesReadings(from: settings, to: updatedSettings))
        
        updatedSettings = settings
        updatedSettings.cpuSensorMode = .die
        XCTAssertTrue(SensorMonitor.changesReadings(from: settings, to: updatedSettings))
    }
    
    // MARK: - Helpers
    private func makeSnapshot(capturedDate: Date? = nil, fanRPM: Double = 1350.0, cpuCelsius: Double? = 45.2, gpuCelsius: Double? = 40.1) -> ReadingsSnapshot {
        let fans: [FanReading] = [FanReading(id: 0, currentRPM: fanRPM, minimumRPM: 1350.0, maximumRPM: 5349.0, targetRPM: 1350.0),]
        return ReadingsSnapshot(capturedDate: capturedDate ?? date,
                                fanStatus: .fans,
                                fans: fans,
                                cpuTemperature: cpuCelsius.map({ TemperatureReading(celsius: $0) }),
                                gpuTemperature: gpuCelsius.map({ TemperatureReading(celsius: $0) }))
    }
}
