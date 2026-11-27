//
//  WidgetTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the widget's staleness, timeline, and the app's reload throttle.
final class WidgetTests: XCTestCase {
    
    private let referenceDate: Date = Date(timeIntervalSinceReferenceDate: 800000000.0)
    
    private func makeSnapshot(capturedDate: Date, rpm: Double = 1350.0, cpuCelsius: Double = 45.2) -> ReadingsSnapshot {
        let fans: [FanReading] = [FanReading(id: 0, currentRPM: rpm, minimumRPM: 1350.0, maximumRPM: 5349.0, targetRPM: rpm),
                                  FanReading(id: 1, currentRPM: 0.0, minimumRPM: 1522.0, maximumRPM: 5777.0, targetRPM: 0.0),]
        return ReadingsSnapshot(capturedDate: capturedDate, fanStatus: .fans, fans: fans, cpuTemperature: TemperatureReading(celsius: cpuCelsius), gpuTemperature: TemperatureReading(celsius: 40.1))
    }
    
    // MARK: - Staleness
    func testSnapshotTurnsStaleAfterAnHour() {
        let snapshot: ReadingsSnapshot = makeSnapshot(capturedDate: referenceDate)
        XCTAssertFalse(snapshot.isStale(at: referenceDate))
        XCTAssertFalse(snapshot.isStale(at: referenceDate.addingTimeInterval(3599.0)))
        XCTAssertTrue(snapshot.isStale(at: referenceDate.addingTimeInterval(3600.0)))
    }
    
    func testSnapshotFromAStoppedAppIsStale() {
        var snapshot: ReadingsSnapshot = makeSnapshot(capturedDate: referenceDate)
        snapshot.stoppedDate = referenceDate
        XCTAssertTrue(snapshot.isStale(at: referenceDate))
        XCTAssertEqual(ReadingsTimeline.entryDates(for: snapshot, now: referenceDate), [referenceDate])
    }
    
    func testSnapshotFromTheFutureIsNotStale() {
        XCTAssertFalse(makeSnapshot(capturedDate: referenceDate.addingTimeInterval(120.0)).isStale(at: referenceDate))
    }
    
    func testWidgetKindNeverChanges() {
        XCTAssertEqual(ReadingsSnapshot.widgetKind, "com.fannywidget.readings")
    }
    
    // MARK: - Timeline
    func testTimelineAddsAMinuteEntryFromTheAgeToStale() {
        let snapshot: ReadingsSnapshot = makeSnapshot(capturedDate: referenceDate)
        let now: Date = referenceDate.addingTimeInterval(30.0)
        let dates: [Date] = ReadingsTimeline.entryDates(for: snapshot, now: now)
        XCTAssertEqual(dates.count, 60)
        XCTAssertEqual(dates[0], now)
        XCTAssertEqual(dates[1], referenceDate.addingTimeInterval(120.0))
        XCTAssertEqual(dates[2], referenceDate.addingTimeInterval(180.0))
        XCTAssertEqual(dates[59], referenceDate.addingTimeInterval(3600.0))
        XCTAssertFalse(ReadingsTimeline.showsAge(of: snapshot, at: dates[0]))
        XCTAssertTrue(ReadingsTimeline.showsAge(of: snapshot, at: dates[1]))
        XCTAssertFalse(snapshot.isStale(at: dates[58]))
        XCTAssertTrue(snapshot.isStale(at: dates[59]))
    }
    
    func testTimelineSkipsMinutesAlreadyPast() {
        let snapshot: ReadingsSnapshot = makeSnapshot(capturedDate: referenceDate)
        let now: Date = referenceDate.addingTimeInterval(3550.0)
        XCTAssertEqual(ReadingsTimeline.entryDates(for: snapshot, now: now), [now, referenceDate.addingTimeInterval(3600.0)])
        XCTAssertTrue(ReadingsTimeline.showsAge(of: snapshot, at: now))
        XCTAssertFalse(ReadingsTimeline.showsAge(of: snapshot, at: referenceDate.addingTimeInterval(119.0)))
    }
    
    func testTimelineOfAStaleOrMissingSnapshotHasOneEntry() {
        let now: Date = referenceDate.addingTimeInterval(3900.0)
        XCTAssertEqual(ReadingsTimeline.entryDates(for: makeSnapshot(capturedDate: referenceDate), now: now), [now])
        XCTAssertEqual(ReadingsTimeline.entryDates(for: nil, now: now), [now])
    }
    
    func testTimelineAsksAgainInFifteenMinutes() {
        XCTAssertEqual(ReadingsTimeline.reloadDate(now: referenceDate), referenceDate.addingTimeInterval(900.0))
    }
    
    // MARK: - Reload Throttle
    func testWidgetReadingsRoundToWholeValues() {
        let readings: WidgetRefresher.WidgetReadings = WidgetRefresher.WidgetReadings(snapshot: makeSnapshot(capturedDate: referenceDate, rpm: 1350.4, cpuCelsius: 45.2), unit: .celsius)
        let sameReadings: WidgetRefresher.WidgetReadings = WidgetRefresher.WidgetReadings(snapshot: makeSnapshot(capturedDate: referenceDate.addingTimeInterval(3.0), rpm: 1349.6, cpuCelsius: 44.9), unit: .celsius)
        let changedReadings: WidgetRefresher.WidgetReadings = WidgetRefresher.WidgetReadings(snapshot: makeSnapshot(capturedDate: referenceDate, rpm: 1350.0, cpuCelsius: 45.6), unit: .celsius)
        XCTAssertEqual(readings, sameReadings)
        XCTAssertNotEqual(readings, changedReadings)
        XCTAssertEqual(readings.cpuTemperature, 45.0)
    }
    
    func testWidgetReadingsUseTheChosenUnit() {
        let readings: WidgetRefresher.WidgetReadings = WidgetRefresher.WidgetReadings(snapshot: makeSnapshot(capturedDate: referenceDate, cpuCelsius: 45.0), unit: .fahrenheit)
        XCTAssertEqual(readings.cpuTemperature, 113.0)
    }
    
    func testReloadWaitsFifteenMinutesInTheBackground() {
        let lastReadings: WidgetRefresher.WidgetReadings = WidgetRefresher.WidgetReadings(snapshot: makeSnapshot(capturedDate: referenceDate), unit: .celsius)
        let changedReadings: WidgetRefresher.WidgetReadings = WidgetRefresher.WidgetReadings(snapshot: makeSnapshot(capturedDate: referenceDate, rpm: 2000.0), unit: .celsius)
        let minimumTimeInterval: TimeInterval = WidgetRefresher.minimumReloadTimeInterval(isAppActive: false, refreshTimeInterval: 4.0)
        XCTAssertEqual(minimumTimeInterval, 900.0)
        XCTAssertFalse(WidgetRefresher.shouldReloadReadings(readings: changedReadings, lastReloadedReadings: lastReadings, lastReloadDate: referenceDate, date: referenceDate.addingTimeInterval(899.0), minimumTimeInterval: minimumTimeInterval))
        XCTAssertTrue(WidgetRefresher.shouldReloadReadings(readings: changedReadings, lastReloadedReadings: lastReadings, lastReloadDate: referenceDate, date: referenceDate.addingTimeInterval(900.0), minimumTimeInterval: minimumTimeInterval))
    }
    
    func testReloadKeepsUpWithEveryReadWhileActive() {
        XCTAssertEqual(WidgetRefresher.minimumReloadTimeInterval(isAppActive: true, refreshTimeInterval: 4.0), 4.0)
    }
    
    func testUnchangedReadingsReloadOnlyEveryFifteenMinutes() {
        let readings: WidgetRefresher.WidgetReadings = WidgetRefresher.WidgetReadings(snapshot: makeSnapshot(capturedDate: referenceDate), unit: .celsius)
        XCTAssertFalse(WidgetRefresher.shouldReloadReadings(readings: readings, lastReloadedReadings: readings, lastReloadDate: referenceDate, date: referenceDate.addingTimeInterval(899.0), minimumTimeInterval: 4.0))
        XCTAssertTrue(WidgetRefresher.shouldReloadReadings(readings: readings, lastReloadedReadings: readings, lastReloadDate: referenceDate, date: referenceDate.addingTimeInterval(900.0), minimumTimeInterval: 4.0))
    }
    
    func testFirstReadAndBackwardClockReload() {
        let readings: WidgetRefresher.WidgetReadings = WidgetRefresher.WidgetReadings(snapshot: makeSnapshot(capturedDate: referenceDate), unit: .celsius)
        let changedReadings: WidgetRefresher.WidgetReadings = WidgetRefresher.WidgetReadings(snapshot: makeSnapshot(capturedDate: referenceDate, rpm: 2000.0), unit: .celsius)
        XCTAssertTrue(WidgetRefresher.shouldReloadReadings(readings: readings, lastReloadedReadings: nil, lastReloadDate: nil, date: referenceDate, minimumTimeInterval: 900.0))
        XCTAssertTrue(WidgetRefresher.shouldReloadReadings(readings: changedReadings, lastReloadedReadings: readings, lastReloadDate: referenceDate, date: referenceDate.addingTimeInterval(-10.0), minimumTimeInterval: 900.0))
    }
    
    func testReloadOnlyWhenTheReadingsWidgetIsPlaced() {
        XCTAssertTrue(WidgetRefresher.containsReadingsWidget(kinds: ["com.fannywidget.readings"]))
        XCTAssertFalse(WidgetRefresher.containsReadingsWidget(kinds: []))
        XCTAssertFalse(WidgetRefresher.containsReadingsWidget(kinds: ["com.fannywidget.placeholder"]))
    }
    
    func testSettingsThatRedrawTheWidget() {
        let settings: FannySettings = FannySettings(locale: Locale(identifier: "en_GB"))
        XCTAssertTrue(WidgetRefresher.changesWidget(from: nil, to: settings))
        
        var unitSettings: FannySettings = settings
        unitSettings.temperatureUnit = .kelvin
        XCTAssertTrue(WidgetRefresher.changesWidget(from: settings, to: unitSettings))
        
        var hiddenSettings: FannySettings = settings
        hiddenSettings.showsGPUTemperature = false
        XCTAssertTrue(WidgetRefresher.changesWidget(from: settings, to: hiddenSettings))
        
        var menuBarSettings: FannySettings = settings
        menuBarSettings.menuBarLayout.setVisible(true, kind: .gpu)
        menuBarSettings.refreshTimeInterval = 10.0
        menuBarSettings.cpuSensorMode = .die
        XCTAssertFalse(WidgetRefresher.changesWidget(from: settings, to: menuBarSettings))
    }
    
    // MARK: - Shared Readings
    func testFastestFanNeedsFans() {
        XCTAssertEqual(makeSnapshot(capturedDate: referenceDate, rpm: 2000.0).fastestFan?.id, 0)
        XCTAssertNil(ReadingsSnapshot(capturedDate: referenceDate, fanStatus: .noFans).fastestFan)
        XCTAssertNil(ReadingsSnapshot.unavailable(at: referenceDate).fastestFan)
    }
    
    func testFanLimitsTextShowsOnlyReportedLimits() {
        let locale: Locale = Locale(identifier: "en_US")
        let fan: FanReading = FanReading(id: 0, currentRPM: 0.0, minimumRPM: 1350.0, maximumRPM: 5349.0, targetRPM: nil)
        let limitsText: ReadingFormatter.SpokenText? = ReadingFormatter.fanLimitsText(fan, locale: locale)
        XCTAssertEqual(limitsText?.text, "Min 1350 · Max 5349 RPM")
        XCTAssertEqual(limitsText?.spokenText, "Minimum 1350, Maximum 5349 revolutions per minute")
        XCTAssertNil(ReadingFormatter.fanLimitsText(FanReading(id: 0, currentRPM: 0.0, minimumRPM: nil, maximumRPM: nil, targetRPM: nil), locale: locale))
    }
}
