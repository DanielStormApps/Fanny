//
//  FannySettingsTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the settings model defaults and decoding.
final class FannySettingsTests: XCTestCase {
    
    func testDefaults() {
        let settings: FannySettings = FannySettings(locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(settings.refreshTimeInterval, 4.0)
        XCTAssertEqual(settings.temperatureUnit, .celsius)
        XCTAssertEqual(settings.menuBarLayout.visibleKinds(fanIDs: [0, 1]), [.icon, .fastestFan])
        XCTAssertEqual(settings.cpuSensorMode, .average)
        XCTAssertEqual(settings.gpuSensorMode, .average)
        XCTAssertTrue(settings.showsCPUTemperature)
        XCTAssertTrue(settings.showsGPUTemperature)
        XCTAssertTrue(settings.checksForUpdatesAutomatically)
    }
    
    func testRegionPicksTheDefaultUnit() {
        XCTAssertEqual(FannySettings.defaultTemperatureUnit(locale: Locale(identifier: "en_US")), .fahrenheit)
        XCTAssertEqual(FannySettings.defaultTemperatureUnit(locale: Locale(identifier: "de_DE")), .celsius)
    }
    
    func testDecodingEmptyObjectUsesDefaults() throws {
        let settings: FannySettings = try JSONDecoder().decode(FannySettings.self, from: Data("{}".utf8))
        XCTAssertEqual(settings, FannySettings())
    }
    
    func testRefreshIntervalIsClampedToWholeSecondsInRange() throws {
        let json: String = #"{"refreshTimeInterval": 7.4, "cpuSensorMode": "hottest"}"#
        let settings: FannySettings = try JSONDecoder().decode(FannySettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.refreshTimeInterval, 7.0)
        XCTAssertEqual(settings.cpuSensorMode, .hottest)
        XCTAssertEqual(FannySettings.clampedRefreshTimeInterval(0.0), 1.0)
        XCTAssertEqual(FannySettings.clampedRefreshTimeInterval(90.0), 60.0)
        XCTAssertEqual(FannySettings.clampedRefreshTimeInterval(TimeInterval.infinity), 4.0)
    }
    
    func testDecodingKeepsSavedValuesAndFillsTheRest() throws {
        let json: String = #"{"temperatureUnit": "kelvin", "menuBarLayout": {"items": [{"kind": {"cpu": {}}, "isVisible": true}]}, "showsGPUTemperature": false}"#
        let settings: FannySettings = try JSONDecoder().decode(FannySettings.self, from: Data(json.utf8))
        var expectedSettings: FannySettings = FannySettings()
        expectedSettings.temperatureUnit = .kelvin
        expectedSettings.menuBarLayout = MenuBarLayout(items: [MenuBarLayout.Item(kind: .icon, isVisible: true),
                                                               MenuBarLayout.Item(kind: .cpu, isVisible: true),
                                                               MenuBarLayout.Item(kind: .fastestFan, isVisible: false),
                                                               MenuBarLayout.Item(kind: .gpu, isVisible: false),])
        expectedSettings.showsGPUTemperature = false
        XCTAssertEqual(settings, expectedSettings)
    }
    
    func testEncodingRoundTrips() throws {
        var settings: FannySettings = FannySettings(locale: Locale(identifier: "en_US"))
        settings.refreshTimeInterval = 10.0
        settings.menuBarLayout.setVisible(true, kind: .cpu)
        settings.menuBarLayout.moveItem(.cpu, before: .fastestFan)
        settings.cpuSensorMode = .average
        settings.gpuSensorMode = .hottest
        settings.showsCPUTemperature = false
        settings.checksForUpdatesAutomatically = false
        let data: Data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(FannySettings.self, from: data), settings)
    }
    
    func testChangedFieldNamesListOnlyChangedFields() {
        let settings: FannySettings = FannySettings(locale: Locale(identifier: "en_GB"))
        var updatedSettings: FannySettings = settings
        XCTAssertTrue(FannySettingsManager.changedFieldNames(from: settings, to: updatedSettings).isEmpty)
        
        updatedSettings.temperatureUnit = .fahrenheit
        updatedSettings.gpuSensorMode = .hottest
        XCTAssertEqual(FannySettingsManager.changedFieldNames(from: settings, to: updatedSettings), ["temperatureUnit", "gpuSensorMode"])
    }
    
    // MARK: - Menu Bar Layout
    func testMenuBarLayoutKeepsTheIconFirstAndAddsFansAfterTheFastestFan() {
        let layout: MenuBarLayout = MenuBarLayout(items: [MenuBarLayout.Item(kind: .cpu, isVisible: true),
                                                          MenuBarLayout.Item(kind: .icon, isVisible: false),
                                                          MenuBarLayout.Item(kind: .cpu, isVisible: false),])
        let normalized: MenuBarLayout = layout.normalized(fanIDs: [0, 1])
        XCTAssertEqual(normalized.items.map({ $0.kind }), [.icon, .cpu, .fastestFan, .fan(id: 0), .fan(id: 1), .gpu])
        XCTAssertEqual(normalized.items.map({ $0.isVisible }), [false, true, false, false, false, false])
        XCTAssertEqual(normalized.visibleKinds(fanIDs: [0, 1]), [.cpu])
        XCTAssertEqual(MenuBarLayout().items(fanIDs: []).map({ $0.kind }), [.icon, .fastestFan, .cpu, .gpu])
    }
    
    func testMenuBarItemsMoveAfterTheIconOnly() {
        var layout: MenuBarLayout = MenuBarLayout()
        layout.moveItem(.gpu, before: .fastestFan)
        XCTAssertEqual(layout.items.map({ $0.kind }), [.icon, .gpu, .fastestFan, .cpu])
        
        layout.moveItem(.cpu, before: .icon)
        layout.moveItem(.icon, before: nil)
        XCTAssertEqual(layout.items.map({ $0.kind }), [.icon, .gpu, .fastestFan, .cpu])
        
        layout.moveItem(.gpu, before: nil)
        XCTAssertEqual(layout.items.map({ $0.kind }), [.icon, .fastestFan, .cpu, .gpu])
        XCTAssertEqual(layout.analyticsValue(fanIDs: []), "icon,fastestFan")
    }
    
    // MARK: - Fan Names
    func testFanNamesFollowTheStyleUnlessRenamed() {
        var settings: FannySettings = FannySettings(locale: Locale(identifier: "en_US"))
        XCTAssertEqual(ReadingFormatter.fanName(id: 1, settings: settings), "Fan 2")
        
        settings.fanNameStyle = .letters
        XCTAssertEqual(ReadingFormatter.fanName(id: 0, settings: settings), "Fan A")
        XCTAssertEqual(ReadingFormatter.fanName(id: 30, settings: settings), "Fan 31")
        
        settings.customFanNames = [0: "🪭"]
        XCTAssertEqual(ReadingFormatter.fanName(id: 0, settings: settings), "🪭")
        XCTAssertEqual(ReadingFormatter.fanName(id: 1, settings: settings), "Fan B")
    }
    
    func testFanNamesAreTrimmedAndCut() throws {
        XCTAssertNil(FannySettings.cleanedFanName("   "))
        XCTAssertEqual(FannySettings.cleanedFanName("  My Awesome Spinny Fan In The Back Corner  "), "My Awesome Spinny Fan In The B")
        XCTAssertEqual(FannySettings.cleanedFanName(String(repeating: "🪭", count: 35))?.count, FannySettings.fanNameMaxLength)
        
        let json: String = #"{"customFanNames": {"0": "  Left  ", "1": "   "}}"#
        let settings: FannySettings = try JSONDecoder().decode(FannySettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.customFanNames, [0: "Left"])
    }
}
