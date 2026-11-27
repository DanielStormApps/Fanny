//
//  SensorReaderTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests how the sensor reader holds a temperature key that briefly drops out.
final class SensorReaderTests: XCTestCase {
    
    private let startDate: Date = Date(timeIntervalSinceReferenceDate: 800000000.0)
    
    func testLiveValuesPassThroughAndAreRecorded() {
        var held: [String: SensorReader.HeldTemperature] = [:]
        let values: [String: Double] = SensorReader.holdingTemperatures(["TCMb": 45.0], heldTemperatures: &held, date: startDate)
        XCTAssertEqual(values, ["TCMb": 45.0])
        XCTAssertEqual(held["TCMb"], SensorReader.HeldTemperature(celsius: 45.0, date: startDate))
    }
    
    func testDroppedKeyIsHeldForTenSeconds() {
        var held: [String: SensorReader.HeldTemperature] = [:]
        _ = SensorReader.holdingTemperatures(["TCMb": 45.0], heldTemperatures: &held, date: startDate)
        
        let heldValues: [String: Double] = SensorReader.holdingTemperatures(["TCMb": 0.0], heldTemperatures: &held, date: startDate.addingTimeInterval(10.0))
        XCTAssertEqual(heldValues, ["TCMb": 45.0])
        
        let missingValues: [String: Double] = SensorReader.holdingTemperatures(["TCMb": nil], heldTemperatures: &held, date: startDate.addingTimeInterval(5.0))
        XCTAssertEqual(missingValues, ["TCMb": 45.0])
    }
    
    func testDroppedKeyIsReleasedAfterTenSeconds() {
        var held: [String: SensorReader.HeldTemperature] = [:]
        _ = SensorReader.holdingTemperatures(["TCMb": 45.0], heldTemperatures: &held, date: startDate)
        
        let values: [String: Double] = SensorReader.holdingTemperatures(["TCMb": 40.0, "Tg0f": nil], heldTemperatures: &held, date: startDate.addingTimeInterval(10.5))
        XCTAssertEqual(values, ["TCMb": 40.0])
        XCTAssertNil(TemperatureSelector.cpuCelsius(values: values, mode: .die))
        XCTAssertTrue(held.isEmpty)
    }
    
    // MARK: - Developer Menu
    /// The In Use table lists only the keys the shown modes read: core keys for Average, die keys for Die and Hottest, and GPU keys while a GPU mode shows.
    func testUsedTemperatureKeysFollowTheShownModes() {
        let die: [String] = ["TCMb"]
        let core: [String] = ["Tp01", "Te04"]
        let gpu: [String] = ["Tg05"]
        
        XCTAssertEqual(SensorReader.usedTemperatureKeyNames(cpuModes: [.average], gpuModes: [.average], cpuDieKeyNames: die, cpuCoreKeyNames: core, gpuKeyNames: gpu), ["Tp01", "Te04", "Tg05"])
        XCTAssertEqual(SensorReader.usedTemperatureKeyNames(cpuModes: [.hottest], gpuModes: [], cpuDieKeyNames: die, cpuCoreKeyNames: core, gpuKeyNames: gpu), ["TCMb"])
        XCTAssertEqual(SensorReader.usedTemperatureKeyNames(cpuModes: [.die, .average], gpuModes: [.hottest], cpuDieKeyNames: die, cpuCoreKeyNames: core, gpuKeyNames: gpu), ["TCMb", "Tp01", "Te04", "Tg05"])
        XCTAssertEqual(SensorReader.usedTemperatureKeyNames(cpuModes: [], gpuModes: [], cpuDieKeyNames: die, cpuCoreKeyNames: core, gpuKeyNames: gpu), [])
    }
}
