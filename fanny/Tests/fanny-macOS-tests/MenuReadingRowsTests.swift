//
//  MenuReadingRowsTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the read only menu rows and the menu bar button for the chosen items.
final class MenuReadingRowsTests: XCTestCase {
    
    private let locale: Locale = Locale(identifier: "en_US")
    
    private let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: Date(timeIntervalSinceReferenceDate: 800000000.0),
                                                              fanStatus: .fans,
                                                              fans: [FanReading(id: 0, currentRPM: 0.0, minimumRPM: 1350.0, maximumRPM: 5349.0, targetRPM: 0.0),
                                                                     FanReading(id: 1, currentRPM: 2410.0, minimumRPM: 1522.0, maximumRPM: 5777.0, targetRPM: nil),],
                                                              cpuTemperature: TemperatureReading(celsius: 45.24),
                                                              gpuTemperature: TemperatureReading(celsius: 40.06))
    
    /// Shows exactly `items` in the menu bar, in that order after the icon.
    private func makeSettings(items: [MenuBarLayout.ItemKind] = [.icon], showsCPU: Bool = true, showsGPU: Bool = true) -> FannySettings {
        var settings: FannySettings = FannySettings(locale: locale)
        settings.temperatureUnit = .celsius
        let allKinds: [MenuBarLayout.ItemKind] = [.icon, .fastestFan, .fan(id: 0), .fan(id: 1), .cpu, .gpu]
        let orderedKinds: [MenuBarLayout.ItemKind] = [.icon] + items.filter({ $0 != .icon }) + allKinds.filter({ items.contains($0) == false && $0 != .icon })
        settings.menuBarLayout = MenuBarLayout(items: orderedKinds.map({ MenuBarLayout.Item(kind: $0, isVisible: items.contains($0)) }))
        settings.showsCPUTemperature = showsCPU
        settings.showsGPUTemperature = showsGPU
        return settings
    }
    
    // MARK: - Rows
    func testFanRowsShowSpeedAndOnlyTheLimitsThatExist() {
        let rows: MenuReadingRows = MenuReadingRows.rows(snapshot: snapshot, settings: makeSettings(), locale: locale)
        XCTAssertEqual(rows.fanRows.map({ $0.title }), ["Fan 1", "Min 1350 · Max 5349 · Target 0 RPM", "Fan 2", "Min 1522 · Max 5777 RPM"])
        XCTAssertEqual(rows.fanRows.map({ $0.style }), [.reading, .detail, .reading, .detail])
        XCTAssertEqual(rows.fanRows[0].value, "Off")
        XCTAssertEqual(rows.fanRows[2].value, "2410 RPM")
        XCTAssertEqual(rows.fanRows[2].accessibilityText, "Fan 2, 2410 revolutions per minute")
        XCTAssertEqual(rows.fanRows[3].accessibilityText, "Minimum 1522, Maximum 5777 revolutions per minute")
    }
    
    func testFanWithNoLimitsHasNoDetailRow() {
        let bareSnapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: Date(), fanStatus: .fans, fans: [FanReading(id: 0, currentRPM: 1200.0, minimumRPM: nil, maximumRPM: nil, targetRPM: nil)])
        let rows: MenuReadingRows = MenuReadingRows.rows(snapshot: bareSnapshot, settings: makeSettings(), locale: locale)
        XCTAssertEqual(rows.fanRows.map({ $0.title }), ["Fan 1"])
    }
    
    func testTemperatureRowsUseOneDecimal() {
        let rows: MenuReadingRows = MenuReadingRows.rows(snapshot: snapshot, settings: makeSettings(), locale: locale)
        XCTAssertEqual(rows.temperatureRows.map({ $0.title }), ["CPU", "GPU"])
        XCTAssertEqual(rows.temperatureRows.map({ $0.value }), ["45.2°C", "40.1°C"])
        XCTAssertEqual(rows.temperatureRows[0].accessibilityText, "CPU, 45.2 degrees Celsius")
    }
    
    func testHiddenTemperaturesDisappearFromRowsAndTooltip() {
        let settings: FannySettings = makeSettings(showsCPU: false, showsGPU: true)
        let rows: MenuReadingRows = MenuReadingRows.rows(snapshot: snapshot, settings: settings, locale: locale)
        XCTAssertEqual(rows.temperatureRows.map({ $0.title }), ["GPU"])
        
        let content: MenuBarButtonContent = MenuBarButtonContent(snapshot: snapshot, settings: settings, locale: locale)
        XCTAssertFalse(content.toolTip.contains("CPU"))
        XCTAssertFalse(content.accessibilityValue.contains("CPU"))
        
        let hiddenRows: MenuReadingRows = MenuReadingRows.rows(snapshot: snapshot, settings: makeSettings(showsCPU: false, showsGPU: false), locale: locale)
        XCTAssertTrue(hiddenRows.temperatureRows.isEmpty)
    }
    
    func testNoFansAndUnavailableShowOneMessage() {
        let noFans: MenuReadingRows = MenuReadingRows.rows(snapshot: ReadingsSnapshot(capturedDate: Date(), fanStatus: .noFans), settings: makeSettings(), locale: locale)
        XCTAssertEqual(noFans.fanRows.map({ $0.title }), ["This Mac Has No Fans"])
        XCTAssertEqual(noFans.fanRows.first?.style, .message)
        
        let unavailable: MenuReadingRows = MenuReadingRows.rows(snapshot: ReadingsSnapshot.unavailable(at: Date()), settings: makeSettings(), locale: locale)
        XCTAssertEqual(unavailable.fanRows.map({ $0.title }), ["Readings Unavailable"])
        XCTAssertEqual(unavailable.temperatureRows.map({ $0.value }), ["--", "--"])
    }
    
    func testNoSnapshotYetShowsReadingMessage() {
        let rows: MenuReadingRows = MenuReadingRows.rows(snapshot: nil, settings: makeSettings(), locale: locale)
        XCTAssertEqual(rows.fanRows.map({ $0.style }), [.message])
        XCTAssertEqual(rows.temperatureRows.map({ $0.value }), ["--", "--"])
    }
    
    func testNewValuesKeepTheLayoutButNewRowsDoNot() {
        let rows: MenuReadingRows = MenuReadingRows.rows(snapshot: snapshot, settings: makeSettings(), locale: locale)
        var fasterSnapshot: ReadingsSnapshot = snapshot
        fasterSnapshot.fans[0].currentRPM = 1400.0
        fasterSnapshot.fans[0].targetRPM = 1400.0
        fasterSnapshot.cpuTemperature = TemperatureReading(celsius: 60.0)
        let fasterRows: MenuReadingRows = MenuReadingRows.rows(snapshot: fasterSnapshot, settings: makeSettings(), locale: locale)
        XCTAssertNotEqual(rows, fasterRows)
        XCTAssertTrue(rows.hasSameLayout(as: fasterRows))
        
        let hiddenRows: MenuReadingRows = MenuReadingRows.rows(snapshot: snapshot, settings: makeSettings(showsGPU: false), locale: locale)
        XCTAssertFalse(rows.hasSameLayout(as: hiddenRows))
        
        let noFansRows: MenuReadingRows = MenuReadingRows.rows(snapshot: ReadingsSnapshot(capturedDate: Date(), fanStatus: .noFans), settings: makeSettings(), locale: locale)
        XCTAssertFalse(rows.hasSameLayout(as: noFansRows))
    }
    
    // MARK: - Button
    func testIconOnlyShowsTheIconAndSpeaksEveryReading() {
        let content: MenuBarButtonContent = MenuBarButtonContent(snapshot: snapshot, settings: makeSettings(items: [.icon]), locale: locale)
        XCTAssertEqual(content.valuesText, "")
        XCTAssertTrue(content.showsIcon)
        XCTAssertEqual(content.accessibilityValue, "Fan 1, Off. Fan 2, 2410 revolutions per minute. CPU, 45.2 degrees Celsius. GPU, 40.1 degrees Celsius")
    }
    
    func testDefaultShowsTheIconAndFastestFan() {
        let content: MenuBarButtonContent = MenuBarButtonContent(snapshot: snapshot, settings: FannySettings(locale: locale), locale: locale)
        XCTAssertTrue(content.showsIcon)
        XCTAssertEqual(content.segments, [MenuBarButtonContent.Segment(label: "RPM", value: "2410")])
        XCTAssertEqual(content.accessibilityValue, "Fastest fan, 2410 revolutions per minute")
    }
    
    func testItemsShowInTheChosenOrderWithLabels() {
        let content: MenuBarButtonContent = MenuBarButtonContent(snapshot: snapshot, settings: makeSettings(items: [.icon, .gpu, .fan(id: 1), .cpu, .fan(id: 0)]), locale: locale)
        XCTAssertEqual(content.valuesText, "40° 2410 45° Off")
        XCTAssertEqual(content.segments.map({ $0.label }), ["GPU", "Fan 2", "CPU", "Fan 1"])
        XCTAssertEqual(content.accessibilityValue, "GPU, 40 degrees Celsius. Fan 2, 2410 revolutions per minute. CPU, 45 degrees Celsius. Fan 1, Off")
    }
    
    func testHidingTheIconLeavesOnlyTheValues() {
        let content: MenuBarButtonContent = MenuBarButtonContent(snapshot: snapshot, settings: makeSettings(items: [.cpu]), locale: locale)
        XCTAssertFalse(content.showsIcon)
        XCTAssertEqual(content.valuesText, "45°")
    }
    
    func testKelvinKeepsItsUnitInTheMenuBar() {
        var settings: FannySettings = makeSettings(items: [.cpu, .gpu])
        settings.temperatureUnit = .kelvin
        XCTAssertEqual(MenuBarButtonContent(snapshot: snapshot, settings: settings, locale: locale).valuesText, "318 K 313 K")
    }
    
    func testTurnedOffTemperatureLeavesAndNothingShownFallsBackToIcon() {
        let cpuOff: MenuBarButtonContent = MenuBarButtonContent(snapshot: snapshot, settings: makeSettings(items: [.cpu, .gpu], showsCPU: false), locale: locale)
        XCTAssertEqual(cpuOff.valuesText, "40°")
        
        let bothOff: MenuBarButtonContent = MenuBarButtonContent(snapshot: snapshot, settings: makeSettings(items: [.cpu, .gpu], showsCPU: false, showsGPU: false), locale: locale)
        XCTAssertEqual(bothOff.valuesText, "")
        XCTAssertTrue(bothOff.showsIcon)
    }
    
    func testFanItems() {
        var stoppedSnapshot: ReadingsSnapshot = snapshot
        stoppedSnapshot.fans[1].currentRPM = 0.0
        XCTAssertEqual(MenuBarButtonContent(snapshot: stoppedSnapshot, settings: makeSettings(items: [.fastestFan]), locale: locale).valuesText, "Off")
        
        let unavailable: MenuBarButtonContent = MenuBarButtonContent(snapshot: ReadingsSnapshot.unavailable(at: Date()), settings: makeSettings(items: [.fastestFan]), locale: locale)
        XCTAssertEqual(unavailable.valuesText, "--")
        
        let noFans: MenuBarButtonContent = MenuBarButtonContent(snapshot: ReadingsSnapshot(capturedDate: Date(), fanStatus: .noFans), settings: makeSettings(items: [.fastestFan, .fan(id: 0)]), locale: locale)
        XCTAssertEqual(noFans.valuesText, "")
        XCTAssertTrue(noFans.showsIcon)
    }
    
    func testNoSnapshotYetShowsDash() {
        XCTAssertEqual(MenuBarButtonContent(snapshot: nil, settings: makeSettings(items: [.cpu, .gpu]), locale: locale).valuesText, "-- --")
        XCTAssertEqual(MenuBarButtonContent(snapshot: nil, settings: makeSettings(items: [.fastestFan]), locale: locale).valuesText, "--")
        
        // A chosen fan keeps its place until a read finds the fans.
        let fanContent: MenuBarButtonContent = MenuBarButtonContent(snapshot: ReadingsSnapshot.unavailable(at: Date()), settings: makeSettings(items: [.fan(id: 1)]), locale: locale)
        XCTAssertEqual(fanContent.segments, [MenuBarButtonContent.Segment(label: "Fan 2", value: "--")])
    }
    
    func testTooltipListsEveryFanThenTemperatures() {
        let content: MenuBarButtonContent = MenuBarButtonContent(snapshot: snapshot, settings: makeSettings(), locale: locale)
        XCTAssertEqual(content.toolTip, "Fan 1: Off\nFan 2: 2410 RPM\nCPU: 45.2°C\nGPU: 40.1°C")
    }
    
    func testSpokenTextIsNeverEmpty() {
        let snapshots: [ReadingsSnapshot?] = [nil,
                                              snapshot,
                                              ReadingsSnapshot.unavailable(at: Date()),
                                              ReadingsSnapshot(capturedDate: Date(), fanStatus: .noFans),]
        
        for candidate in snapshots {
            for items in [[MenuBarLayout.ItemKind.icon], [.fastestFan], [.cpu, .gpu], [.fan(id: 0)]] {
                let content: MenuBarButtonContent = MenuBarButtonContent(snapshot: candidate, settings: makeSettings(items: items), locale: locale)
                XCTAssertFalse(content.accessibilityValue.isEmpty)
                XCTAssertFalse(content.toolTip.isEmpty)
            }
        }
    }
}

// MARK: - MenuBarButtonContent
private extension MenuBarButtonContent {
    
    /// The values without their labels, as the menu bar shows them from left to right.
    var valuesText: String {
        return segments.map({ $0.value }).joined(separator: " ")
    }
}
