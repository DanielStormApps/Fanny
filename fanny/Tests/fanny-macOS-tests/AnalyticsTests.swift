//
//  AnalyticsTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the shared analytics parameters, and that they never carry a reading.
final class AnalyticsTests: XCTestCase {
    
    func testSettingsParametersSendEveryChoice() {
        var settings: FannySettings = FannySettings(locale: Locale(identifier: "en_GB"))
        settings.menuBarLayout.setVisible(false, kind: .icon)
        settings.menuBarLayout.setVisible(true, kind: .gpu)
        settings.menuBarLayout.moveItem(.gpu, before: .fastestFan)
        settings.refreshTimeInterval = 10.0
        settings.fanNameStyle = .letters
        settings.customFanNames = [0: "Left"]
        settings.temperatureUnit = .kelvin
        settings.showsCPUTemperature = false
        settings.cpuSensorMode = .hottest
        settings.gpuSensorMode = .average
        settings.checksForUpdatesAutomatically = false
        
        let parameters: [String: String] = AnalyticsSharedParameters.settingsParameters(settings)
        XCTAssertEqual(parameters[AnalyticsParameter.menuBarItems], "gpu,fastestFan")
        XCTAssertEqual(parameters[AnalyticsParameter.refreshInterval], "10")
        XCTAssertEqual(parameters[AnalyticsParameter.temperatureUnit], "kelvin")
        XCTAssertEqual(parameters[AnalyticsParameter.cpuTemperature], "disabled")
        XCTAssertEqual(parameters[AnalyticsParameter.cpuSensor], "hottest")
        XCTAssertEqual(parameters[AnalyticsParameter.gpuTemperature], "enabled")
        XCTAssertEqual(parameters[AnalyticsParameter.gpuSensor], "average")
        XCTAssertEqual(parameters[AnalyticsParameter.automaticUpdateChecks], "disabled")
        XCTAssertEqual(parameters[AnalyticsParameter.floatingWindow], "disabled")
        XCTAssertEqual(parameters[AnalyticsParameter.floatingWindowLayout], "vertical")
        XCTAssertEqual(parameters[AnalyticsParameter.floatingWindowCards], "cpu:temp|gpu:temp")
        XCTAssertEqual(parameters[AnalyticsParameter.fanNameStyle], "letters")
        XCTAssertEqual(parameters[AnalyticsParameter.customFanNames], "1")
        XCTAssertEqual(parameters.count, 13)
    }
    
    func testFanCount() {
        let date: Date = Date(timeIntervalSince1970: 0.0)
        let fans: [FanReading] = [FanReading(id: 0, currentRPM: 1350.0, minimumRPM: 1350.0, maximumRPM: 5349.0, targetRPM: 1350.0),
                                  FanReading(id: 1, currentRPM: 0.0, minimumRPM: 1522.0, maximumRPM: 5777.0, targetRPM: 0.0),]
        XCTAssertEqual(AnalyticsSharedParameters.fanCount(snapshot: ReadingsSnapshot(capturedDate: date, fanStatus: .fans, fans: fans)), "2")
        XCTAssertEqual(AnalyticsSharedParameters.fanCount(snapshot: ReadingsSnapshot(capturedDate: date, fanStatus: .noFans)), "0")
        XCTAssertEqual(AnalyticsSharedParameters.fanCount(snapshot: ReadingsSnapshot(capturedDate: date, fanStatus: .unavailable)), "unspecified")
        XCTAssertEqual(AnalyticsSharedParameters.fanCount(snapshot: nil), "unspecified")
    }
    
    func testSharedParametersCarryNoReadings() {
        let parameters: [String: String] = AnalyticsSharedParameters.parameters()
        let readingWords: [String] = ["rpm",
                                      "celsius",
                                      "speed",
                                      "degrees",]
        
        for key in parameters.keys {
            for word in readingWords {
                XCTAssertFalse(key.lowercased().contains(word), "\(key) looks like a reading")
            }
        }
        
        XCTAssertNotNil(parameters[AnalyticsParameter.fanCount])
        XCTAssertNotNil(parameters[AnalyticsParameter.temperatureUnit])
        // Firebase drops an event that carries more than 25 parameters, and each event adds up to 4 of its own.
        XCTAssertLessThanOrEqual(parameters.count, 21)
    }
    
    // MARK: - Privacy Switch
    /// The off event goes out before any bridge stops, the on event after every bridge starts, and nothing is sent in between.
    func testTurningAnalyticsOffAndOnSendsBothEvents() {
        let wasEnabled: Bool = Analytics.shared.isEnabled
        defer { Analytics.shared.setEnabled(wasEnabled, event: PageViewEvent(title: "test_Restore")) }
        
        Analytics.shared.setEnabled(true, event: PageViewEvent(title: "test_Setup"))
        let bridge: RecordingAnalyticsBridge = RecordingAnalyticsBridge(trackingIDs: [])
        Analytics.shared.add(bridge: bridge)
        
        Analytics.shared.setEnabled(false, event: PageViewEvent(title: "privacy_AnalyticsOff"))
        XCTAssertFalse(Analytics.shared.isEnabled)
        XCTAssertTrue(Storage.bool(forKey: .analyticsDisabled))
        
        Analytics.shared.track(event: PageViewEvent(title: "general_FloatingWindow"))
        Analytics.shared.setEnabled(false, event: PageViewEvent(title: "privacy_AnalyticsOffAgain"))
        
        Analytics.shared.setEnabled(true, event: PageViewEvent(title: "privacy_AnalyticsOn"))
        XCTAssertTrue(Analytics.shared.isEnabled)
        XCTAssertFalse(Storage.bool(forKey: .analyticsDisabled))
        
        XCTAssertEqual(bridge.calls, ["track privacy_AnalyticsOff",
                                      "setEnabled false",
                                      "setEnabled true",
                                      "track privacy_AnalyticsOn",])
    }
    
    /// The crash reports off event goes out before they stop and the on event after they start, and neither goes out while Analytics is off.
    func testTurningCrashReportsOffAndOnSendsBothEvents() {
        let wasAnalyticsEnabled: Bool = Analytics.shared.isEnabled
        let wasCrashReportsEnabled: Bool = FirebaseManager.shared.isCrashReportsEnabled
        let wasOffReportPending: Bool = Storage.bool(forKey: .crashReportsOffReportPending)
        defer {
            Analytics.shared.setEnabled(wasAnalyticsEnabled, event: PageViewEvent(title: "test_Restore"))
            FirebaseManager.shared.setCrashReportsEnabled(wasCrashReportsEnabled, event: PageViewEvent(title: "test_Restore"))
            Storage.save(wasOffReportPending, forKey: .crashReportsOffReportPending)
        }
        
        Analytics.shared.setEnabled(true, event: PageViewEvent(title: "test_Setup"))
        FirebaseManager.shared.setCrashReportsEnabled(true, event: PageViewEvent(title: "test_Setup"))
        let bridge: RecordingAnalyticsBridge = RecordingAnalyticsBridge(trackingIDs: [])
        Analytics.shared.add(bridge: bridge)
        
        FirebaseManager.shared.setCrashReportsEnabled(false, event: PageViewEvent(title: "privacy_CrashReportsOff"))
        XCTAssertFalse(FirebaseManager.shared.isCrashReportsEnabled)
        XCTAssertTrue(Storage.bool(forKey: .crashReportsDisabled))
        XCTAssertTrue(Storage.bool(forKey: .crashReportsOffReportPending))
        XCTAssertTrue(Analytics.shared.isEnabled)
        
        FirebaseManager.shared.setCrashReportsEnabled(false, event: PageViewEvent(title: "privacy_CrashReportsOffAgain"))
        
        FirebaseManager.shared.setCrashReportsEnabled(true, event: PageViewEvent(title: "privacy_CrashReportsOn"))
        XCTAssertTrue(FirebaseManager.shared.isCrashReportsEnabled)
        XCTAssertFalse(Storage.bool(forKey: .crashReportsDisabled))
        XCTAssertFalse(Storage.bool(forKey: .crashReportsOffReportPending))
        
        Analytics.shared.setEnabled(false, event: PageViewEvent(title: "privacy_AnalyticsOff"))
        FirebaseManager.shared.setCrashReportsEnabled(false, event: PageViewEvent(title: "privacy_CrashReportsOffWithoutAnalytics"))
        FirebaseManager.shared.setCrashReportsEnabled(true, event: PageViewEvent(title: "privacy_CrashReportsOnWithoutAnalytics"))
        
        XCTAssertEqual(bridge.calls, ["track privacy_CrashReportsOff",
                                      "track privacy_CrashReportsOn",
                                      "track privacy_AnalyticsOff",
                                      "setEnabled false",])
    }
}

// MARK: - RecordingAnalyticsBridge
/// Records every call in order, so a test can check what was sent before and after analytics changed.
private final class RecordingAnalyticsBridge: AnalyticsBridge {
    
    private(set) var calls: [String] = []
    
    required init(trackingIDs: [String]) {}
    
    func trackEvent(_ event: AnalyticsEvent) {
        guard let event: PageViewEvent = event as? PageViewEvent else { return }
        calls.append("track \(event.title ?? "")")
    }
    
    func setEnabled(_ isEnabled: Bool) {
        calls.append("setEnabled \(isEnabled)")
    }
}
