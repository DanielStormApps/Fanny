//
//  AppIntentSupport.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// Thrown when an intent has no reading to answer with, so a Shortcut never gets a made up value.
struct ReadingUnavailableError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    let message: String
    
    /// - Note: Wraps the already localized `message`; a plain key would be looked up in the presenting process and fall back to English.
    var localizedStringResource: LocalizedStringResource {
        return "\(message)"
    }
}

/// Shared analytics and spoken text for the App Intents, kept free of UI so it can be tested.
enum AppIntentSupport {
    
    enum Temperature {
        case cpu
        case gpu
    }
    
    /// A temperature in the chosen unit, rounded to one decimal like the spoken text.
    struct TemperatureAnswer: Equatable {
        let value: Double
        let spokenText: String
    }
    
    /// One fan's speed in RPM, 0 when it is off, and the sentence Siri says.
    struct FanSpeedAnswer: Equatable {
        let rpm: Double
        let spokenText: String
    }
    
    // MARK: - Analytics
    static func track(_ title: String) {
        let event: PageViewEvent = PageViewEvent(title: title)
        Analytics.shared.track(event: event)
    }
    
    // MARK: - Fan Speeds
    /// One "Fan 1: 1350 RPM" line per fan for Shortcuts, and a sentence per fan for Siri.
    /// - Throws: `ReadingUnavailableError` when the fans could not be read.
    static func fanSpeedsAnswer(snapshot: ReadingsSnapshot, settings: FannySettings, locale: Locale = Locale.current) throws -> ReadingFormatter.SpokenText {
        let answer: ReadingFormatter.SpokenText
        
        switch snapshot.fanStatus {
        case .fans where snapshot.fans.isEmpty == false:
            let lines: [String] = snapshot.fans.map({ fanSpeedLine($0, settings: settings, locale: locale) })
            let sentences: [String] = snapshot.fans.map({ spokenFanSpeedSentence($0, settings: settings, locale: locale) })
            answer = ReadingFormatter.SpokenText(text: lines.joined(separator: "\n"), spokenText: sentences.joined(separator: " "))
        case .fans, .noFans:
            let text: String = String(localized: "This Mac has no fans.", comment: "Siri and Shortcuts: the answer to a fan speed request on a Mac without fans, such as a MacBook Air.")
            answer = ReadingFormatter.SpokenText(text: text, spokenText: text)
        case .unavailable:
            let message: String = String(localized: "Fanny couldn't read the fan speeds.", comment: "Siri and Shortcuts: error when the fan speeds could not be read.")
            throw ReadingUnavailableError(message: message)
        }
        
        return answer
    }
    
    /// One fan's speed in RPM and the sentence Siri says.
    /// - Throws: `ReadingUnavailableError` when the fans could not be read or this fan is gone.
    static func fanSpeedAnswer(fanID: Int, snapshot: ReadingsSnapshot, settings: FannySettings, locale: Locale = Locale.current) throws -> FanSpeedAnswer {
        guard
            snapshot.fanStatus == ReadingsSnapshot.FanStatus.fans,
            let fan: FanReading = snapshot.fans.first(where: { $0.id == fanID })
        else {
            let message: String = String(localized: "Fanny couldn't read the fan speeds.", comment: "Siri and Shortcuts: error when the fan speeds could not be read.")
            throw ReadingUnavailableError(message: message)
        }
        
        return FanSpeedAnswer(rpm: fan.isStopped ? 0.0 : fan.currentRPM.rounded(), spokenText: spokenFanSpeedSentence(fan, settings: settings, locale: locale))
    }
    
    private static func fanSpeedLine(_ fan: FanReading, settings: FannySettings, locale: Locale) -> String {
        let name: String = ReadingFormatter.fanName(id: fan.id, settings: settings)
        let speedText: String = ReadingFormatter.fanSpeedText(fan, locale: locale)
        return String(localized: "\(name): \(speedText)", comment: "Shortcuts: one line per fan in the fan speed result, such as Fan 1: 1350 RPM. The first argument is the fan's name, the second its speed or Off.")
    }
    
    private static func spokenFanSpeedSentence(_ fan: FanReading, settings: FannySettings, locale: Locale) -> String {
        let name: String = ReadingFormatter.fanName(id: fan.id, settings: settings)
        let sentence: String
        
        if fan.isStopped {
            sentence = String(localized: "\(name) is off.", comment: "Siri: spoken for a fan that is not spinning. The argument is the fan's name, such as Fan 1.")
        }
        else {
            let speedText: String = ReadingFormatter.spokenRPMText(fan.currentRPM, locale: locale)
            sentence = String(localized: "\(name) is at \(speedText).", comment: "Siri: spoken speed of one fan. The first argument is the fan's name, such as Fan 1, the second its speed, such as 1350 revolutions per minute.")
        }
        
        return sentence
    }
    
    // MARK: - Readings
    /// Every reading Fanny shows: the fans, then the temperatures that are not hidden. One line each for Shortcuts, and sentences for Siri.
    /// - Throws: `ReadingUnavailableError` when nothing could be read.
    static func readingsAnswer(snapshot: ReadingsSnapshot, settings: FannySettings, locale: Locale = Locale.current) throws -> ReadingFormatter.SpokenText {
        var lines: [String] = []
        var sentences: [String] = []
        
        if let fanAnswer: ReadingFormatter.SpokenText = try? fanSpeedsAnswer(snapshot: snapshot, settings: settings, locale: locale) {
            lines.append(fanAnswer.text)
            sentences.append(fanAnswer.spokenText)
        }
        
        for temperature in [Temperature.cpu, Temperature.gpu] {
            guard let answer: TemperatureAnswer = try? temperatureAnswer(temperature, snapshot: snapshot, settings: settings, locale: locale) else { continue }
            let reading: TemperatureReading? = temperature == Temperature.cpu ? snapshot.cpuTemperature : snapshot.gpuTemperature
            let title: String = temperature == Temperature.cpu ? ReadingFormatter.cpuTitle : ReadingFormatter.gpuTitle
            let valueText: String = ReadingFormatter.temperatureText(reading, unit: settings.temperatureUnit, style: .full, locale: locale)
            lines.append(String(localized: "\(title): \(valueText)", comment: "Shortcuts: one line in the readings result, such as CPU: 45.2°C. The first argument is CPU or GPU, the second the temperature."))
            sentences.append(answer.spokenText)
        }
        
        guard lines.isEmpty == false else {
            let message: String = String(localized: "Fanny couldn't read the sensors.", comment: "Siri and Shortcuts: error when no fan speed or temperature could be read.")
            throw ReadingUnavailableError(message: message)
        }
        
        return ReadingFormatter.SpokenText(text: lines.joined(separator: "\n"), spokenText: sentences.joined(separator: " "))
    }
    
    // MARK: - Settings
    static func menuBarItemChangedText(_ kind: MenuBarLayout.ItemKind, isShown: Bool) -> String {
        let title: String = MenuBarSettingsViewController.title(for: kind)
        let text: String
        
        if isShown {
            text = String(localized: "The menu bar now shows \(title).", comment: "Siri: spoken confirmation after showing an item in the menu bar. The argument is the item, such as CPU Temperature.")
        }
        else {
            text = String(localized: "The menu bar no longer shows \(title).", comment: "Siri: spoken confirmation after hiding an item from the menu bar. The argument is the item, such as CPU Temperature.")
        }
        
        return text
    }
    
    static func temperatureUnitChangedText(_ unit: FannySettings.TemperatureUnit) -> String {
        let title: String = SensorSettingsViewController.title(for: unit)
        return String(localized: "Fanny now shows temperatures in \(title).", comment: "Siri: spoken confirmation after changing the temperature unit. The argument is the unit, such as Celsius (°C).")
    }
    
    static func refreshIntervalChangedText(_ timeInterval: TimeInterval) -> String {
        let title: String = SensorSettingsViewController.refreshTitle(for: timeInterval)
        return String(localized: "Fanny now refreshes every \(title).", comment: "Siri: spoken confirmation after changing how often Fanny reads the sensors. The argument is a duration, such as 4 seconds.")
    }
    
    static func cpuSensorChangedText(_ mode: FannySettings.CPUSensorMode) -> String {
        let title: String = SensorSettingsViewController.title(for: mode)
        return String(localized: "The CPU sensor is now \(title).", comment: "Siri: spoken confirmation after changing the CPU temperature sensor. The argument is the sensor, such as Hottest.")
    }
    
    static func gpuSensorChangedText(_ mode: FannySettings.GPUSensorMode) -> String {
        let title: String = SensorSettingsViewController.title(for: mode)
        return String(localized: "The GPU sensor is now \(title).", comment: "Siri: spoken confirmation after changing the GPU temperature sensor. The argument is the sensor, such as Average.")
    }
    
    // MARK: - Temperatures
    /// The temperature in the chosen unit and the sentence Siri says.
    /// - Throws: `ReadingUnavailableError` when the temperature is turned off in Settings or could not be read.
    static func temperatureAnswer(_ temperature: Temperature, snapshot: ReadingsSnapshot, settings: FannySettings, locale: Locale = Locale.current) throws -> TemperatureAnswer {
        let isShown: Bool = temperature == Temperature.cpu ? settings.showsCPUTemperature : settings.showsGPUTemperature
        let reading: TemperatureReading? = temperature == Temperature.cpu ? snapshot.cpuTemperature : snapshot.gpuTemperature
        
        guard isShown, let reading: TemperatureReading = reading else {
            throw ReadingUnavailableError(message: temperatureUnavailableText(temperature, isShown: isShown))
        }
        
        let unit: FannySettings.TemperatureUnit = settings.temperatureUnit
        let value: Double = (reading.value(in: unit) * 10.0).rounded(.toNearestOrAwayFromZero) / 10.0
        let temperatureText: String = ReadingFormatter.spokenTemperatureText(reading, unit: unit, style: .full, locale: locale)
        let spokenText: String
        
        switch temperature {
        case .cpu:
            spokenText = String(localized: "Your CPU temperature is \(temperatureText).", comment: "Siri: spoken CPU temperature. The argument is a temperature such as 45.2 degrees Celsius.")
        case .gpu:
            spokenText = String(localized: "Your GPU temperature is \(temperatureText).", comment: "Siri: spoken GPU temperature. The argument is a temperature such as 45.2 degrees Celsius.")
        }
        
        return TemperatureAnswer(value: value, spokenText: spokenText)
    }
    
    /// A hidden temperature is not read at all, so the answer says where to turn it back on.
    static func temperatureUnavailableText(_ temperature: Temperature, isShown: Bool) -> String {
        let text: String
        
        switch (temperature, isShown) {
        case (.cpu, false):
            text = String(localized: "CPU Temperature is turned off in Fanny's Sensors settings.", comment: "Siri and Shortcuts: error when the CPU temperature is hidden. CPU Temperature and Sensors name the switch and the Settings pane.")
        case (.gpu, false):
            text = String(localized: "GPU Temperature is turned off in Fanny's Sensors settings.", comment: "Siri and Shortcuts: error when the GPU temperature is hidden. GPU Temperature and Sensors name the switch and the Settings pane.")
        case (.cpu, true):
            text = String(localized: "Fanny couldn't read the CPU temperature.", comment: "Siri and Shortcuts: error when the CPU temperature could not be read.")
        case (.gpu, true):
            text = String(localized: "Fanny couldn't read the GPU temperature.", comment: "Siri and Shortcuts: error when the GPU temperature could not be read.")
        }
        
        return text
    }
}
