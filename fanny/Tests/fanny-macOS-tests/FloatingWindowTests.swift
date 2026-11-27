//
//  FloatingWindowTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the floating window's layout, what it reads, what it draws, and how it resizes.
final class FloatingWindowTests: XCTestCase {
    
    private let date: Date = Date(timeIntervalSince1970: 0.0)
    private let locale: Locale = Locale(identifier: "en_US")
    
    // MARK: - Layout
    func testDefaultLayoutLeadsWithEachFanThenBothTemperatures() {
        let layout: FloatingWindowLayout = FloatingWindowLayout()
        let cards: [FloatingWindowLayout.Card] = layout.visibleCards(fanIDs: [0, 1])
        XCTAssertEqual(layout.orientation, .vertical)
        XCTAssertEqual(cards.map({ $0.kind }), [.fan(id: 0), .fan(id: 1), .cpu, .gpu])
        XCTAssertEqual(cards.map({ $0.visibleStats }), [[.fanSpeed], [.fanSpeed], [.cpuTemperature], [.gpuTemperature]])
    }
    
    func testNewFanJoinsTheOtherFans() {
        var layout: FloatingWindowLayout = FloatingWindowLayout().normalized(fanIDs: [0])
        layout.moveCard(.fan(id: 0), before: .gpu)
        XCTAssertEqual(layout.normalized(fanIDs: [0, 1]).cards.map({ $0.kind }), [.cpu, .fan(id: 0), .fan(id: 1), .gpu])
    }
    
    func testFanCardsForMissingFansAreKeptButNotShown() {
        let layout: FloatingWindowLayout = FloatingWindowLayout().normalized(fanIDs: [0, 1])
        XCTAssertEqual(layout.cards.count, 4)
        XCTAssertEqual(layout.cards(fanIDs: [0]).map({ $0.kind }), [.fan(id: 0), .cpu, .gpu])
        XCTAssertEqual(layout.cards(fanIDs: []).map({ $0.kind }), [.cpu, .gpu])
    }
    
    func testNormalizingDropsDuplicatesAndFillsMissingStatsHidden() {
        let card: FloatingWindowLayout.Card = FloatingWindowLayout.Card(kind: .cpu, isVisible: true, stats: [FloatingWindowLayout.StatItem(stat: .cpuDie, isVisible: true),
                                                                                                               FloatingWindowLayout.StatItem(stat: .cpuDie, isVisible: false),
                                                                                                               FloatingWindowLayout.StatItem(stat: .fanSpeed, isVisible: true),])
        let layout: FloatingWindowLayout = FloatingWindowLayout(orientation: .vertical, cards: [card, card]).normalized(fanIDs: [])
        XCTAssertEqual(layout.cards.map({ $0.kind }), [.cpu, .gpu])
        XCTAssertEqual(layout.cards[0].stats.map({ $0.stat }), [.cpuDie, .cpuTemperature, .cpuAverage, .cpuHottest])
        XCTAssertEqual(layout.cards[0].visibleStats, [.cpuDie])
        XCTAssertEqual(layout.orientation, .vertical)
    }
    
    func testMovingCardsAndStats() {
        var layout: FloatingWindowLayout = FloatingWindowLayout().normalized(fanIDs: [0])
        layout.moveCard(.fan(id: 0), before: .cpu)
        XCTAssertEqual(layout.cards.map({ $0.kind }), [.fan(id: 0), .cpu, .gpu])
        layout.moveCard(.fan(id: 0), before: nil)
        XCTAssertEqual(layout.cards.map({ $0.kind }), [.cpu, .gpu, .fan(id: 0)])
        
        layout.moveStat(.cpuAverage, before: .cpuTemperature, kind: .cpu)
        XCTAssertEqual(layout.cards[0].stats.first?.stat, .cpuAverage)
        layout.moveStat(.cpuAverage, before: nil, kind: .cpu)
        XCTAssertEqual(layout.cards[0].stats.last?.stat, .cpuAverage)
    }
    
    func testHidingEveryStatHidesTheCard() {
        var layout: FloatingWindowLayout = FloatingWindowLayout()
        layout.setStatVisible(false, stat: .gpuTemperature, kind: .gpu)
        layout.setCardVisible(false, kind: .cpu)
        XCTAssertEqual(layout.visibleCards(fanIDs: []).count, 0)
        XCTAssertEqual(layout.analyticsValue(fanIDs: []), "none")
    }
    
    func testLayoutSurvivesAnUnknownStatInSavedData() throws {
        let json: String = #"{"orientation": "sideways", "cards": [{"kind": {"cpu": {}}, "isVisible": true, "stats": [{"stat": "cpuFuture", "isVisible": true}]}]}"#
        let layout: FloatingWindowLayout = try JSONDecoder().decode(FloatingWindowLayout.self, from: Data(json.utf8))
        XCTAssertEqual(layout.orientation, .vertical)
        XCTAssertEqual(layout.cards.map({ $0.kind }), [.cpu, .gpu])
    }
    
    // MARK: - Reading
    func testOnlyShownTemperaturesAreRead() {
        var settings: FannySettings = FannySettings(locale: locale)
        settings.showsCPUTemperature = false
        settings.showsGPUTemperature = false
        XCTAssertEqual(settings.cpuModesToRead, [])
        XCTAssertEqual(settings.gpuModesToRead, [])
        
        settings.showsFloatingWindow = true
        settings.cpuSensorMode = .hottest
        settings.floatingWindowLayout.setStatVisible(true, stat: .cpuAverage, kind: .cpu)
        settings.floatingWindowLayout.setStatVisible(true, stat: .gpuHottest, kind: .gpu)
        // Turned off in Sensors stays off, even with floating window cards that show it.
        XCTAssertEqual(settings.cpuModesToRead, [])
        XCTAssertEqual(settings.gpuModesToRead, [])
        
        settings.showsCPUTemperature = true
        settings.showsGPUTemperature = true
        XCTAssertEqual(settings.cpuModesToRead, [.average, .hottest])
        XCTAssertEqual(settings.gpuModesToRead, [.average, .hottest])
    }
    
    func testCardOfATurnedOffTemperatureSaysSo() {
        var settings: FannySettings = FannySettings(locale: locale)
        settings.showsGPUTemperature = false
        let content: FloatingWindowContent = FloatingWindowContent(snapshot: ReadingsSnapshot(capturedDate: date, fanStatus: .noFans), settings: settings, locale: locale)
        XCTAssertEqual(content.cards.map({ $0.isTurnedOff }), [false, true])
        XCTAssertTrue(content.cards[1].rows.isEmpty)
        XCTAssertEqual(content.cards[1].spokenText, "GPU, Turned off in Fanny's Sensors settings")
    }
    
    func testChangingTheCardsTriggersARead() {
        var settings: FannySettings = FannySettings(locale: locale)
        settings.showsFloatingWindow = true
        var changedSettings: FannySettings = settings
        changedSettings.floatingWindowLayout.setStatVisible(true, stat: .cpuDie, kind: .cpu)
        XCTAssertTrue(SensorMonitor.changesReadings(from: settings, to: changedSettings))
        
        var reorderedSettings: FannySettings = settings
        reorderedSettings.floatingWindowLayout.moveCard(.gpu, before: .cpu)
        XCTAssertFalse(SensorMonitor.changesReadings(from: settings, to: reorderedSettings))
    }
    
    // MARK: - Content
    func testContentFormatsEachStat() {
        var settings: FannySettings = FannySettings(locale: locale)
        settings.temperatureUnit = .celsius
        settings.cpuSensorMode = .die
        settings.floatingWindowLayout = FloatingWindowLayout().normalized(fanIDs: [0])
        settings.floatingWindowLayout.setStatVisible(true, stat: .cpuAverage, kind: .cpu)
        settings.floatingWindowLayout.setStatVisible(true, stat: .fanSpeedBar, kind: .fan(id: 0))
        settings.floatingWindowLayout.setStatVisible(true, stat: .fanMaximum, kind: .fan(id: 0))
        settings.floatingWindowLayout.setCardVisible(false, kind: .gpu)
        
        let fan: FanReading = FanReading(id: 0, currentRPM: 3349.0, minimumRPM: 1349.0, maximumRPM: 5349.0, targetRPM: 3349.0)
        let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: date, fanStatus: .fans, fans: [fan], cpuTemperatures: [.die: TemperatureReading(celsius: 52.4), .average: TemperatureReading(celsius: 48.6)])
        let content: FloatingWindowContent = FloatingWindowContent(snapshot: snapshot, settings: settings, locale: locale)
        
        XCTAssertEqual(content.cards.map({ $0.title }), ["Fan 1", "CPU"])
        XCTAssertEqual(content.cards[0].rows.map({ $0.style }), [.value("3349 RPM"), .bar(0.5), .value("5349 RPM")])
        XCTAssertEqual(content.cards[0].rows[1].spokenText, "Speed Bar, 50%")
        XCTAssertEqual(content.cards[1].rows.map({ $0.style }), [.value("52°"), .value("49°")])
    }
    
    func testContentWithoutFansOrSelectionsIsEmpty() {
        var settings: FannySettings = FannySettings(locale: locale)
        settings.floatingWindowLayout.setCardVisible(false, kind: .cpu)
        settings.floatingWindowLayout.setCardVisible(false, kind: .gpu)
        let content: FloatingWindowContent = FloatingWindowContent(snapshot: ReadingsSnapshot(capturedDate: date, fanStatus: .noFans), settings: settings, locale: locale)
        XCTAssertTrue(content.cards.isEmpty)
        XCTAssertEqual(content.spokenText, FloatingWindowContent.emptyText)
    }
    
    func testValueChangesKeepTheLayout() {
        let row: FloatingWindowContent.Row = FloatingWindowContent.Row(stat: .cpuTemperature, title: "Temperature", style: .value("52°"), spokenText: "")
        let changedRow: FloatingWindowContent.Row = FloatingWindowContent.Row(stat: .cpuTemperature, title: "Temperature", style: .value("53°"), spokenText: "")
        let content: FloatingWindowContent = FloatingWindowContent(orientation: .horizontal, cards: [FloatingWindowContent.Card(kind: .cpu, title: "CPU", symbol: .cpu, rows: [row])])
        let changedContent: FloatingWindowContent = FloatingWindowContent(orientation: .horizontal, cards: [FloatingWindowContent.Card(kind: .cpu, title: "CPU", symbol: .cpu, rows: [changedRow])])
        let stackedContent: FloatingWindowContent = FloatingWindowContent(orientation: .vertical, cards: content.cards)
        XCTAssertTrue(FloatingWindowViewController.hasSameLayout(content, changedContent))
        XCTAssertFalse(FloatingWindowViewController.hasSameLayout(content, stackedContent))
        XCTAssertTrue(FloatingWindowViewController.hasSameCards(content, stackedContent))
    }
    
    /// A fan name change, such as switching Fan Names to Letters or typing a custom name, has to rebuild the card, since updating in place only changes values.
    func testRenamedFanChangesTheLayout() {
        var settings: FannySettings = FannySettings(locale: locale)
        let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: date, fanStatus: .fans, fans: [FanReading(id: 0, currentRPM: 2000.0, minimumRPM: 1000.0, maximumRPM: 5000.0, targetRPM: 2000.0)])
        let content: FloatingWindowContent = FloatingWindowContent(snapshot: snapshot, settings: settings, locale: locale)
        settings.fanNameStyle = .letters
        let lettersContent: FloatingWindowContent = FloatingWindowContent(snapshot: snapshot, settings: settings, locale: locale)
        
        XCTAssertEqual(content.cards.first?.title, "Fan 1")
        XCTAssertEqual(lettersContent.cards.first?.title, "Fan A")
        XCTAssertFalse(FloatingWindowViewController.hasSameLayout(content, lettersContent))
        
        settings.customFanNames[0] = "Left 🌀"
        let customContent: FloatingWindowContent = FloatingWindowContent(snapshot: snapshot, settings: settings, locale: locale)
        XCTAssertEqual(customContent.cards.first?.title, "Left 🌀")
        XCTAssertFalse(FloatingWindowViewController.hasSameLayout(lettersContent, customContent))
    }
    
    // MARK: - Position
    func testResizingGrowsAwayFromTheNearerEdgeAndStaysOnScreen() {
        let visibleFrame: CGRect = CGRect(x: 0.0, y: 0.0, width: 1000.0, height: 800.0)
        let rightFrame: CGRect = CGRect(x: 800.0, y: 700.0, width: 180.0, height: 80.0)
        XCTAssertEqual(FloatingWindowController.resizedFrame(rightFrame, to: CGSize(width: 400.0, height: 100.0), in: visibleFrame), CGRect(x: 580.0, y: 680.0, width: 400.0, height: 100.0))
        
        let leftFrame: CGRect = CGRect(x: 20.0, y: 700.0, width: 180.0, height: 80.0)
        XCTAssertEqual(FloatingWindowController.resizedFrame(leftFrame, to: CGSize(width: 400.0, height: 100.0), in: visibleFrame), CGRect(x: 20.0, y: 680.0, width: 400.0, height: 100.0))
        
        let wideFrame: CGRect = CGRect(x: 600.0, y: 700.0, width: 100.0, height: 80.0)
        XCTAssertEqual(FloatingWindowController.resizedFrame(wideFrame, to: CGSize(width: 600.0, height: 80.0), in: visibleFrame).maxX, 700.0)
    }
}
