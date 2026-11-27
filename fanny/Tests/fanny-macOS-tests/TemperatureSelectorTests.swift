//
//  TemperatureSelectorTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the CPU and GPU temperature selection rules against real SMC dumps.
final class TemperatureSelectorTests: XCTestCase {
    
    private static let accuracy: Double = 0.0001
    
    func testLivenessRange() {
        XCTAssertTrue(TemperatureSelector.isLive(15.0))
        XCTAssertTrue(TemperatureSelector.isLive(45.2))
        XCTAssertTrue(TemperatureSelector.isLive(120.0))
        XCTAssertTrue(TemperatureSelector.isLive(40.01))
        XCTAssertFalse(TemperatureSelector.isLive(40.0))
        XCTAssertFalse(TemperatureSelector.isLive(14.9))
        XCTAssertFalse(TemperatureSelector.isLive(120.1))
        XCTAssertFalse(TemperatureSelector.isLive(6.7))
        XCTAssertFalse(TemperatureSelector.isLive(-55.1))
        XCTAssertFalse(TemperatureSelector.isLive(Double.nan))
        XCTAssertFalse(TemperatureSelector.isLive(Double.infinity))
    }
    
    func testKeyFamilies() {
        XCTAssertTrue(TemperatureSelector.isCPUDieKey("TCMb"))
        XCTAssertTrue(TemperatureSelector.isCPUDieKey("TCMz"))
        XCTAssertFalse(TemperatureSelector.isCPUDieKey("TVD0"))
        XCTAssertTrue(TemperatureSelector.isCPUCoreKey("Tp0A"))
        XCTAssertTrue(TemperatureSelector.isCPUCoreKey("Te05"))
        XCTAssertTrue(TemperatureSelector.isCPUCoreKey("Tm0P"))
        XCTAssertTrue(TemperatureSelector.isCPUCoreKey("Tf04"))
        XCTAssertFalse(TemperatureSelector.isCPUCoreKey("Tf06"))
        XCTAssertFalse(TemperatureSelector.isCPUCoreKey("TCMb"))
        XCTAssertTrue(TemperatureSelector.isGPUKey("Tg0f"))
        XCTAssertTrue(TemperatureSelector.isGPUKey("Tf14"))
        XCTAssertFalse(TemperatureSelector.isGPUKey("Tf16"))
        XCTAssertFalse(TemperatureSelector.isGPUKey("Tg0"))
    }
    
    func testMemoryKeysCountOnlyWithoutEfficiencyKeys() {
        // M4 lists Te keys, so its Tm keys are memory.
        XCTAssertEqual(TemperatureSelector.cpuCoreKeyNames(["Tp01", "Te05", "Tm0p"]), ["Tp01", "Te05"])
        // M5 Pro and Max list no Te keys, so their Tm keys are CPU clusters.
        XCTAssertEqual(TemperatureSelector.cpuCoreKeyNames(["Tp00", "Tm00"]), ["Tp00", "Tm00"])
    }
    
    func testFabricFallbacksCountOnlyWithoutTheirFamily() {
        // M3 lists no Tp or Tg keys, so its Tf cluster and GPU keys stand in.
        XCTAssertEqual(TemperatureSelector.cpuCoreKeyNames(["Te05", "Tf04", "Tf44"]), ["Te05", "Tf04", "Tf44"])
        XCTAssertEqual(TemperatureSelector.gpuKeyNames(["Tf14", "Tf24"]), ["Tf14", "Tf24"])
        // Chips with Tp and Tg keys, such as M2 Max, also list these Tf keys but never count them.
        XCTAssertEqual(TemperatureSelector.cpuCoreKeyNames(["Tp01", "Te05", "Tf04"]), ["Tp01", "Te05"])
        XCTAssertEqual(TemperatureSelector.gpuKeyNames(["Tg0f", "Tf14"]), ["Tg0f"])
    }
    
    func testFabricFallbacksAreReadLikeCores() {
        let values: [String: Double] = ["Te05": 41.0,
                                        "Tf04": 50.0,
                                        "Tf09": 54.0,
                                        "Tf44": 60.0,]
        // One value per family: Te0 41, Tf0 54, Tf4 60.
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .average)!, 51.666667, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .hottest)!, 60.0, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.gpuCelsius(values: ["Tf14": 45.0, "Tf24": 47.0], mode: .hottest)!, 47.0, accuracy: TemperatureSelectorTests.accuracy)
    }
    
    func testCPUAtIdle() {
        let values: [String: Double] = SensorFixtures.idle
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .die)!, 37.348625, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .hottest)!, 46.721874, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .average)!, 40.963541, accuracy: TemperatureSelectorTests.accuracy)
    }
    
    func testCPUUnderLoad() {
        let values: [String: Double] = SensorFixtures.cpuLoad
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .die)!, 56.539135, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .hottest)!, 61.01875, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .average)!, 50.836718, accuracy: TemperatureSelectorTests.accuracy)
    }
    
    func testGPUAtIdleAndUnderLoad() {
        XCTAssertEqual(TemperatureSelector.gpuCelsius(values: SensorFixtures.idle, mode: .average)!, 36.331831, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.gpuCelsius(values: SensorFixtures.idle, mode: .hottest)!, 36.918262, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.gpuCelsius(values: SensorFixtures.cpuLoad, mode: .average)!, 42.270062, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.gpuCelsius(values: SensorFixtures.gpuLoad, mode: .average)!, 52.359775, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.gpuCelsius(values: SensorFixtures.gpuLoad, mode: .hottest)!, 52.89541, accuracy: TemperatureSelectorTests.accuracy)
    }
    
    func testAverageFallsBackToTheDieWhenNoCoreIsLive() {
        let dieValues: [String: Double] = ["TCMb": 47.5,
                                           "TCMz": 52.0,
                                           "Tp01": 0.0,]
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: dieValues, mode: .average)!, 47.5, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: ["TCMz": 52.0], mode: .average)!, 52.0, accuracy: TemperatureSelectorTests.accuracy)
    }
    
    /// In a cold room the die can read under the live range. It still shows for Average and Die, while 0.0 still reads as missing.
    func testColdDieShowsInsteadOfADash() {
        let values: [String: Double] = ["TCMb": 12.5, "Tp01": 6.7, "Te04": 0.0]
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .average)!, 12.5, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .die)!, 12.5, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertNil(TemperatureSelector.cpuCelsius(values: ["TCMb": 0.0], mode: .die))
    }
    
    func testHottestFallsBackToTheWarmestCore() {
        var values: [String: Double] = SensorFixtures.cpuLoad
        values["TCMb"] = 0.0
        values["TCMz"] = nil
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .average)!, 50.836718, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .hottest)!, 61.01875, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertNil(TemperatureSelector.cpuCelsius(values: values, mode: .die))
    }
    
    func testPlaceholderValuesAreIgnored() {
        let values: [String: Double] = SensorFixtures.maxChipPlaceholder
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .average)!, 33.25, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertNil(TemperatureSelector.cpuCelsius(values: values, mode: .die))
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .hottest)!, 35.5, accuracy: TemperatureSelectorTests.accuracy)
        XCTAssertNil(TemperatureSelector.gpuCelsius(values: values, mode: .average))
        XCTAssertNil(TemperatureSelector.gpuCelsius(values: values, mode: .hottest))
    }
    
    func testAverageCountsEachFamilyOnce() {
        // Tp0a is an offset copy of Tp0A, so the Tp0 family counts as 50.0 once.
        let values: [String: Double] = ["Tp0A": 44.3,
                                        "Tp0a": 50.0,
                                        "Tp1A": 30.0,]
        XCTAssertEqual(TemperatureSelector.cpuCelsius(values: values, mode: .average)!, 40.0, accuracy: TemperatureSelectorTests.accuracy)
    }
    
    func testOtherFamiliesNeverCount() {
        let values: [String: Double] = ["Tf06": 81.984375,
                                        "Tf16": 61.78125,
                                        "TVD0": 37.3,
                                        "Th00": 29.3,]
        
        for mode in FannySettings.CPUSensorMode.allCases {
            XCTAssertNil(TemperatureSelector.cpuCelsius(values: values, mode: mode))
        }
        
        for mode in FannySettings.GPUSensorMode.allCases {
            XCTAssertNil(TemperatureSelector.gpuCelsius(values: values, mode: mode))
        }
    }
    
    func testNoValuesReadAsMissing() {
        XCTAssertNil(TemperatureSelector.cpuCelsius(values: [:], mode: .average))
        XCTAssertNil(TemperatureSelector.gpuCelsius(values: [:], mode: .average))
    }
}
