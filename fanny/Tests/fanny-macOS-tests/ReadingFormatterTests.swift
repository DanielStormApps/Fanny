//
//  ReadingFormatterTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the fan speed and temperature texts.
final class ReadingFormatterTests: XCTestCase {
    
    private let locale: Locale = Locale(identifier: "en_US")
    private let temperature: TemperatureReading = TemperatureReading(celsius: 45.24)
    
    // MARK: - Fan Speed
    func testRPMIsGroupedWithNoDecimals() {
        XCTAssertEqual(ReadingFormatter.rpmText(1350.4, locale: locale), "1350 RPM")
        XCTAssertEqual(ReadingFormatter.rpmText(5349.5, locale: locale), "5350 RPM")
        XCTAssertEqual(ReadingFormatter.rpmText(0.0, locale: locale), "0 RPM")
        XCTAssertEqual(ReadingFormatter.rpmNumberText(-0.4, locale: locale), "0")
    }
    
    func testRPMNeverGroupsThousands() {
        XCTAssertEqual(ReadingFormatter.rpmNumberText(1350.0, locale: Locale(identifier: "de_DE")), "1350")
        XCTAssertEqual(ReadingFormatter.rpmNumberText(12345.0, locale: Locale(identifier: "en_US")), "12345")
    }
    
    func testSpokenRPMNamesTheUnit() {
        XCTAssertEqual(ReadingFormatter.spokenRPMText(1350.0, locale: locale), "1350 revolutions per minute")
    }
    
    func testStoppedFanReadsOff() {
        let fan: FanReading = FanReading(id: 0, currentRPM: 0.0, minimumRPM: 1350.0, maximumRPM: 5349.0, targetRPM: 0.0)
        XCTAssertEqual(ReadingFormatter.fanSpeedText(fan, locale: locale), "Off")
        XCTAssertEqual(ReadingFormatter.spokenFanSpeedText(fan, locale: locale), "Off")
    }
    
    func testSpinningFanReadsItsSpeed() {
        let fan: FanReading = FanReading(id: 1, currentRPM: 2410.6, minimumRPM: 1522.0, maximumRPM: 5777.0, targetRPM: 2400.0)
        XCTAssertEqual(ReadingFormatter.fanSpeedText(fan, locale: locale), "2411 RPM")
        XCTAssertEqual(ReadingFormatter.spokenFanSpeedText(fan, locale: locale), "2411 revolutions per minute")
    }
    
    func testMissingFanReadsAsDash() {
        XCTAssertEqual(ReadingFormatter.fanSpeedText(nil, locale: locale), "--")
        XCTAssertFalse(ReadingFormatter.spokenFanSpeedText(nil, locale: locale).isEmpty)
    }
    
    // MARK: - Temperature
    func testCompactTemperatureForEachUnit() {
        XCTAssertEqual(ReadingFormatter.temperatureText(temperature, unit: .celsius, style: .compact, locale: locale), "45°")
        XCTAssertEqual(ReadingFormatter.temperatureText(temperature, unit: .fahrenheit, style: .compact, locale: locale), "113°")
        XCTAssertEqual(ReadingFormatter.temperatureText(temperature, unit: .kelvin, style: .compact, locale: locale), "318 K")
    }
    
    func testFullTemperatureForEachUnitHasOneDecimal() {
        XCTAssertEqual(ReadingFormatter.temperatureText(temperature, unit: .celsius, style: .full, locale: locale), "45.2°C")
        XCTAssertEqual(ReadingFormatter.temperatureText(temperature, unit: .fahrenheit, style: .full, locale: locale), "113.4°F")
        XCTAssertEqual(ReadingFormatter.temperatureText(temperature, unit: .kelvin, style: .full, locale: locale), "318.4 K")
        XCTAssertEqual(ReadingFormatter.temperatureText(TemperatureReading(celsius: 40.0), unit: .celsius, style: .full, locale: locale), "40.0°C")
    }
    
    func testCompactTemperatureRoundsHalfUp() {
        XCTAssertEqual(ReadingFormatter.temperatureText(TemperatureReading(celsius: 44.5), unit: .celsius, style: .compact, locale: locale), "45°")
        XCTAssertEqual(ReadingFormatter.temperatureText(TemperatureReading(celsius: 44.49), unit: .celsius, style: .compact, locale: locale), "44°")
    }
    
    func testTemperatureDecimalFollowsTheLocale() {
        XCTAssertEqual(ReadingFormatter.temperatureText(temperature, unit: .celsius, style: .full, locale: Locale(identifier: "de_DE")), "45,2°C")
    }
    
    func testSpokenTemperatureNamesEachUnit() {
        XCTAssertEqual(ReadingFormatter.spokenTemperatureText(temperature, unit: .celsius, style: .full, locale: locale), "45.2 degrees Celsius")
        XCTAssertEqual(ReadingFormatter.spokenTemperatureText(temperature, unit: .fahrenheit, style: .full, locale: locale), "113.4 degrees Fahrenheit")
        XCTAssertEqual(ReadingFormatter.spokenTemperatureText(temperature, unit: .kelvin, style: .full, locale: locale), "318.4 kelvins")
        XCTAssertEqual(ReadingFormatter.spokenTemperatureText(temperature, unit: .celsius, style: .compact, locale: locale), "45 degrees Celsius")
    }
    
    func testMissingTemperatureReadsAsDash() {
        for unit in FannySettings.TemperatureUnit.allCases {
            XCTAssertEqual(ReadingFormatter.temperatureText(nil, unit: unit, style: .compact, locale: locale), "--")
            XCTAssertEqual(ReadingFormatter.temperatureText(nil, unit: unit, style: .full, locale: locale), "--")
            XCTAssertFalse(ReadingFormatter.spokenTemperatureText(nil, unit: unit, style: .full, locale: locale).isEmpty)
        }
    }
}
