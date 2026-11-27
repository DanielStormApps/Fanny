//
//  AppIntentSupportTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the text and values the App Shortcuts answer with.
final class AppIntentSupportTests: XCTestCase {
    
    private let locale: Locale = Locale(identifier: "en_US")
    private let date: Date = Date(timeIntervalSince1970: 1_800_000_000.0)
    
    // MARK: - Fan Speeds
    func testFanSpeedsListEveryFan() throws {
        let fans: [FanReading] = [FanReading(id: 0, currentRPM: 1350.4, minimumRPM: 1350.0, maximumRPM: 5349.0, targetRPM: 1350.0),
                                  FanReading(id: 1, currentRPM: 0.0, minimumRPM: 1522.0, maximumRPM: 5777.0, targetRPM: 0.0),]
        let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: date, fanStatus: .fans, fans: fans)
        let answer: ReadingFormatter.SpokenText = try AppIntentSupport.fanSpeedsAnswer(snapshot: snapshot, settings: FannySettings(locale: locale), locale: locale)
        XCTAssertEqual(answer.text, "Fan 1: 1350 RPM\nFan 2: Off")
        XCTAssertEqual(answer.spokenText, "Fan 1 is at 1350 revolutions per minute. Fan 2 is off.")
    }
    
    func testFanSpeedsOnAMacWithNoFans() throws {
        let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: date, fanStatus: .noFans)
        let answer: ReadingFormatter.SpokenText = try AppIntentSupport.fanSpeedsAnswer(snapshot: snapshot, settings: FannySettings(locale: locale), locale: locale)
        XCTAssertEqual(answer.text, "This Mac has no fans.")
        XCTAssertEqual(answer.spokenText, answer.text)
    }
    
    func testFanSpeedsThrowWhenUnavailable() {
        XCTAssertThrowsError(try AppIntentSupport.fanSpeedsAnswer(snapshot: ReadingsSnapshot.unavailable(at: date), settings: FannySettings(locale: locale), locale: locale)) { error in
            let message: String = (error as? ReadingUnavailableError)?.message ?? ""
            XCTAssertFalse(message.isEmpty)
        }
    }
    
    // MARK: - Temperatures
    func testTemperatureUsesTheChosenUnit() throws {
        var settings: FannySettings = FannySettings(locale: locale)
        settings.temperatureUnit = .fahrenheit
        let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: date, fanStatus: .noFans, cpuTemperature: TemperatureReading(celsius: 45.24), gpuTemperature: TemperatureReading(celsius: 40.06))
        
        let cpuAnswer: AppIntentSupport.TemperatureAnswer = try AppIntentSupport.temperatureAnswer(.cpu, snapshot: snapshot, settings: settings, locale: locale)
        XCTAssertEqual(cpuAnswer.value, 113.4, accuracy: 0.0001)
        XCTAssertEqual(cpuAnswer.spokenText, "Your CPU temperature is 113.4 degrees Fahrenheit.")
        
        settings.temperatureUnit = .celsius
        let gpuAnswer: AppIntentSupport.TemperatureAnswer = try AppIntentSupport.temperatureAnswer(.gpu, snapshot: snapshot, settings: settings, locale: locale)
        XCTAssertEqual(gpuAnswer.value, 40.1, accuracy: 0.0001)
        XCTAssertEqual(gpuAnswer.spokenText, "Your GPU temperature is 40.1 degrees Celsius.")
        
        settings.temperatureUnit = .kelvin
        let kelvinAnswer: AppIntentSupport.TemperatureAnswer = try AppIntentSupport.temperatureAnswer(.cpu, snapshot: snapshot, settings: settings, locale: locale)
        XCTAssertEqual(kelvinAnswer.value, 318.4, accuracy: 0.0001)
        XCTAssertTrue(kelvinAnswer.spokenText.contains("kelvins"))
    }
    
    func testHiddenTemperatureThrowsAndSaysWhereToTurnItOn() {
        var settings: FannySettings = FannySettings(locale: locale)
        settings.showsGPUTemperature = false
        let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: date, fanStatus: .noFans, cpuTemperature: TemperatureReading(celsius: 45.0), gpuTemperature: TemperatureReading(celsius: 40.0))
        
        XCTAssertThrowsError(try AppIntentSupport.temperatureAnswer(.gpu, snapshot: snapshot, settings: settings, locale: locale)) { error in
            XCTAssertEqual(error as? ReadingUnavailableError, ReadingUnavailableError(message: AppIntentSupport.temperatureUnavailableText(.gpu, isShown: false)))
        }
        XCTAssertNoThrow(try AppIntentSupport.temperatureAnswer(.cpu, snapshot: snapshot, settings: settings, locale: locale))
    }
    
    func testMissingTemperatureThrows() {
        let settings: FannySettings = FannySettings(locale: locale)
        let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: date, fanStatus: .noFans)
        
        XCTAssertThrowsError(try AppIntentSupport.temperatureAnswer(.cpu, snapshot: snapshot, settings: settings, locale: locale)) { error in
            XCTAssertEqual(error as? ReadingUnavailableError, ReadingUnavailableError(message: AppIntentSupport.temperatureUnavailableText(.cpu, isShown: true)))
        }
    }
    
    func testUnavailableTextsAreDistinctAndNeverEmpty() {
        let texts: [String] = [AppIntentSupport.temperatureUnavailableText(.cpu, isShown: false),
                               AppIntentSupport.temperatureUnavailableText(.gpu, isShown: false),
                               AppIntentSupport.temperatureUnavailableText(.cpu, isShown: true),
                               AppIntentSupport.temperatureUnavailableText(.gpu, isShown: true),]
        XCTAssertEqual(Set(texts).count, texts.count)
        XCTAssertFalse(texts.contains(where: { $0.isEmpty }))
    }
    
    // MARK: - Fan Speed, Readings, and Settings
    func testFanSpeedAnswer() throws {
        let fans: [FanReading] = [FanReading(id: 0, currentRPM: 1350.4, minimumRPM: 1350.0, maximumRPM: 5349.0, targetRPM: 1350.0),
                                  FanReading(id: 1, currentRPM: 0.0, minimumRPM: 1522.0, maximumRPM: 5777.0, targetRPM: 0.0),]
        let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: date, fanStatus: .fans, fans: fans)
        XCTAssertEqual(try AppIntentSupport.fanSpeedAnswer(fanID: 0, snapshot: snapshot, settings: FannySettings(locale: locale), locale: locale).rpm, 1350.0)
        XCTAssertEqual(try AppIntentSupport.fanSpeedAnswer(fanID: 1, snapshot: snapshot, settings: FannySettings(locale: locale), locale: locale).rpm, 0.0)
        XCTAssertThrowsError(try AppIntentSupport.fanSpeedAnswer(fanID: 2, snapshot: snapshot, settings: FannySettings(locale: locale), locale: locale))
    }
    
    func testReadingsAnswerListsFansThenTemperatures() throws {
        var settings: FannySettings = FannySettings(locale: locale)
        settings.temperatureUnit = .celsius
        settings.showsGPUTemperature = false
        let fans: [FanReading] = [FanReading(id: 0, currentRPM: 0.0, minimumRPM: 1350.0, maximumRPM: 5349.0, targetRPM: 0.0)]
        let snapshot: ReadingsSnapshot = ReadingsSnapshot(capturedDate: date, fanStatus: .fans, fans: fans, cpuTemperature: TemperatureReading(celsius: 45.24))
        let answer: ReadingFormatter.SpokenText = try AppIntentSupport.readingsAnswer(snapshot: snapshot, settings: settings, locale: locale)
        XCTAssertEqual(answer.text, "Fan 1: Off\nCPU: 45.2°C")
        XCTAssertThrowsError(try AppIntentSupport.readingsAnswer(snapshot: ReadingsSnapshot.unavailable(at: date), settings: settings, locale: locale))
    }
}
