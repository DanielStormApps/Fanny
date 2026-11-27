//
//  SettingsTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the settings panes, their input rules, and related helpers.
final class SettingsTests: XCTestCase {
    
    func testStoredValueRestoresPane() {
        XCTAssertEqual(SettingsPane(storedValue: "about"), SettingsPane.about)
        XCTAssertEqual(SettingsPane(storedValue: "appearance"), SettingsPane.appearance)
    }
    
    func testMissingOrUnknownStoredValueFallsBackToGeneral() {
        XCTAssertEqual(SettingsPane(storedValue: nil), SettingsPane.general)
        XCTAssertEqual(SettingsPane(storedValue: "unknown"), SettingsPane.general)
    }
    
    func testEveryPaneRoundTripsItsRawValue() {
        for pane in SettingsPane.allCases {
            XCTAssertEqual(SettingsPane(storedValue: pane.rawValue), pane)
            XCTAssertFalse(pane.title.isEmpty)
        }
    }
    
    func testPanesAreListedInSidebarOrder() {
        XCTAssertEqual(SettingsPane.allCases, [SettingsPane.general,
                                               SettingsPane.sensors,
                                               SettingsPane.menuBar,
                                               SettingsPane.floatingWindow,
                                               SettingsPane.appearance,
                                               SettingsPane.privacy,
                                               SettingsPane.faq,
                                               SettingsPane.about,])
        XCTAssertEqual(SettingsPane(storedValue: "menuBar"), SettingsPane.menuBar)
        XCTAssertEqual(SettingsPane(storedValue: "sensors"), SettingsPane.sensors)
    }
    
    func testRefreshTitlesSpellOutTheInterval() {
        let locale: Locale = Locale(identifier: "en_US")
        let titles: [String] = [1.0, 4.0, 60.0].map({ SensorSettingsViewController.refreshTitle(for: $0, locale: locale) })
        XCTAssertEqual(titles, ["1 second",
                                "4 seconds",
                                "1 minute",])
    }
    
    func testSecondsFieldAcceptsOnlyWholeSecondsInRange() {
        XCTAssertEqual(SettingsSecondsControl.parsedSeconds(from: " 12 ", in: FannySettings.refreshSecondsRange), 12)
        XCTAssertNil(SettingsSecondsControl.parsedSeconds(from: "0", in: FannySettings.refreshSecondsRange))
        XCTAssertNil(SettingsSecondsControl.parsedSeconds(from: "61", in: FannySettings.refreshSecondsRange))
        XCTAssertNil(SettingsSecondsControl.parsedSeconds(from: "1.5", in: FannySettings.refreshSecondsRange))
    }
    
    func testEveryChoiceHasADistinctTitle() {
        let menuBarKinds: [MenuBarLayout.ItemKind] = [.icon, .fastestFan, .fan(id: 0), .fan(id: 1), .cpu, .gpu]
        let displayTitles: [String] = menuBarKinds.map({ MenuBarSettingsViewController.title(for: $0) })
        let unitTitles: [String] = FannySettings.TemperatureUnit.allCases.map({ SensorSettingsViewController.title(for: $0) })
        let cpuTitles: [String] = FannySettings.CPUSensorMode.allCases.map({ SensorSettingsViewController.title(for: $0) })
        let gpuTitles: [String] = FannySettings.GPUSensorMode.allCases.map({ SensorSettingsViewController.title(for: $0) })
        
        for titles in [displayTitles, unitTitles, cpuTitles, gpuTitles] {
            XCTAssertEqual(Set(titles).count, titles.count)
            XCTAssertFalse(titles.contains(where: { $0.isEmpty }))
        }
    }
    
    func testPopUpRowTakesTheRowTitleAsItsName() {
        let popUpButton: NSPopUpButton = NSPopUpButton(frame: CGRect.zero, pullsDown: false)
        popUpButton.addItem(withTitle: "Celsius (°C)")
        _ = SettingsRowView(title: "Temperature Unit", control: popUpButton)
        XCTAssertEqual(popUpButton.accessibilityLabel(), "Temperature Unit")
        
        let button: NSButton = NSButton(title: "Visit", target: nil, action: nil)
        _ = SettingsRowView(title: "Website", control: button)
        XCTAssertEqual(button.accessibilityHelp(), "Website")
    }
    
    func testGroupHidesRowTogetherWithItsSeparator() {
        let group: SettingsGroupView = SettingsGroupView()
        let first: SettingsRowView = SettingsRowView(title: "First")
        let second: SettingsRowView = SettingsRowView(title: "Second")
        group.addRow(first)
        group.addRow(second)
        
        group.setRowHidden(second, hidden: true)
        XCTAssertTrue(second.isHidden)
        
        group.setRowHidden(second, hidden: false)
        XCTAssertFalse(second.isHidden)
    }
    
    func testGroupReportsWhetherAnyRowIsVisible() {
        let group: SettingsGroupView = SettingsGroupView()
        let first: SettingsRowView = SettingsRowView(title: "First")
        let second: SettingsRowView = SettingsRowView(title: "Second")
        group.addRow(first)
        group.addRow(second)
        XCTAssertTrue(group.hasVisibleRows)
        
        group.setRowHidden(first, hidden: true)
        group.setRowHidden(second, hidden: true)
        XCTAssertFalse(group.hasVisibleRows)
        
        group.setRowHidden(second, hidden: false)
        XCTAssertTrue(group.hasVisibleRows)
    }
    
    func testScrollViewHidesGroupWithItsSection() {
        let scrollView: SettingsScrollView = SettingsScrollView()
        let group: SettingsGroupView = SettingsGroupView()
        scrollView.addGroup(group, footer: "Footer")
        
        scrollView.setGroupHidden(group, hidden: true)
        XCTAssertEqual(group.superview?.isHidden, true)
        
        scrollView.setGroupHidden(group, hidden: false)
        XCTAssertEqual(group.superview?.isHidden, false)
    }
    
    // MARK: - Positive Promo
    func testPositiveWaitsForOneCalendarDay() {
        var calendar: Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let lateNight: Date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 23, minute: 30))!
        let sameDay: Date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 23, minute: 59))!
        let nextMorning: Date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 0, minute: 5))!
        
        XCTAssertFalse(PositiveApp.daysExceeded(initialSessionDate: nil, now: nextMorning, calendar: calendar))
        XCTAssertFalse(PositiveApp.daysExceeded(initialSessionDate: lateNight, now: sameDay, calendar: calendar))
        XCTAssertTrue(PositiveApp.daysExceeded(initialSessionDate: lateNight, now: nextMorning, calendar: calendar))
    }
    
    // MARK: - GitHub Issues
    /// Each form opens with its template and label, and every value is encoded so a `+` or `&` never splits or changes it.
    func testIssueLinksPrefillTheTemplateFields() {
        let fields: [(GitHubIssue.Field, String)] = [(GitHubIssue.Field.fannyVersion, "26.1.0 (26010000)"),
                                                     (GitHubIssue.Field.chip, "Apple M5 Pro+ & Max"),]
        let url: URL? = GitHubIssue.url(kind: .problem, gitHubPath: "https://github.com/DanielStormApps/Fanny", fields: fields)
        XCTAssertEqual(url?.absoluteString, "https://github.com/DanielStormApps/Fanny/issues/new?template=bug_report.yml&labels=bug&fanny-version=26.1.0%20(26010000)&chip=Apple%20M5%20Pro%2B%20%26%20Max")
        
        let featureURL: URL? = GitHubIssue.url(kind: .featureRequest, gitHubPath: "https://github.com/DanielStormApps/Fanny", fields: [])
        XCTAssertEqual(featureURL?.absoluteString, "https://github.com/DanielStormApps/Fanny/issues/new?template=feature_request.yml&labels=feature%20request")
    }
    
    func testCurrentIssueFieldsDescribeThisMac() {
        let fields: [GitHubIssue.Field: String] = Dictionary(uniqueKeysWithValues: GitHubIssue.currentFields().map({ ($0.0, $0.1) }))
        XCTAssertEqual(fields[.fannyVersion], "\(Bundle.version) (\(Bundle.buildNumber))")
        XCTAssertNotNil(fields[.macOSVersion])
        XCTAssertTrue(fields[.macModel]?.hasPrefix("Mac") ?? false)
        XCTAssertTrue(fields[.chip]?.hasPrefix("Apple") ?? false)
    }
}
