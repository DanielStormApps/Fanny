//
//  ReadingFormatter.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// Turns fan speeds and temperatures into the texts the menu bar, menu, tooltip, widget, and Siri show.
enum ReadingFormatter {
    
    enum TemperatureStyle {
        /// Whole degrees without the unit letter, such as "45°", for the menu bar and widget. Kelvin keeps " K", since "318°" would read as a wrong value.
        case compact
        /// One decimal with the unit, such as "45.2°C", for the menu rows and the tooltip.
        case full
    }
    
    /// A text and its twin for VoiceOver, which names every unit.
    struct SpokenText: Equatable {
        let text: String
        let spokenText: String
    }
    
    /// Shown in place of any value that is missing or hidden.
    static let missingText: String = "--"
    
    // MARK: - Fan Speed
    /// A whole number with no unit, such as "1350". A slightly negative read shows as 0.
    static func rpmNumberText(_ rpm: Double, locale: Locale = Locale.current) -> String {
        return numberText(max(rpm, 0.0), fractionLength: 0, locale: locale)
    }
    
    /// Such as "1350 RPM".
    static func rpmText(_ rpm: Double, locale: Locale = Locale.current) -> String {
        return rpmText(numberText: rpmNumberText(rpm, locale: locale))
    }
    
    /// Adds the unit to text that is already formatted, such as one number or a list of them.
    static func rpmText(numberText: String) -> String {
        return String(localized: "\(numberText) RPM", comment: "A fan speed or a list of fan speeds in revolutions per minute. The argument is a number such as 1350 or a list such as Min 1350 · Max 5349.")
    }
    
    /// Such as "1350 revolutions per minute", for VoiceOver and Siri.
    static func spokenRPMText(_ rpm: Double, locale: Locale = Locale.current) -> String {
        return spokenRPMText(numberText: rpmNumberText(rpm, locale: locale))
    }
    
    static func spokenRPMText(numberText: String) -> String {
        return String(localized: "\(numberText) revolutions per minute", comment: "Spoken fan speed or list of fan speeds for VoiceOver and Siri. The argument is a number such as 1350 or a list such as Minimum 1350, Maximum 5349.")
    }
    
    /// Off for a stopped fan, since Apple silicon fans rest at 0 RPM until they are needed.
    static func fanSpeedText(_ fan: FanReading?, locale: Locale = Locale.current) -> String {
        let text: String
        
        if let fan: FanReading = fan {
            text = fan.isStopped ? offText : rpmText(fan.currentRPM, locale: locale)
        }
        else {
            text = missingText
        }
        
        return text
    }
    
    /// The speed without its unit, such as "1350", for the menu bar, where a label under it names the fan.
    static func compactFanSpeedText(_ fan: FanReading?, locale: Locale = Locale.current) -> String {
        let text: String
        
        if let fan: FanReading = fan {
            text = fan.isStopped ? offText : rpmNumberText(fan.currentRPM, locale: locale)
        }
        else {
            text = missingText
        }
        
        return text
    }
    
    static func spokenFanSpeedText(_ fan: FanReading?, locale: Locale = Locale.current) -> String {
        let text: String
        
        if let fan: FanReading = fan {
            text = fan.isStopped ? offText : spokenRPMText(fan.currentRPM, locale: locale)
        }
        else {
            text = spokenMissingText
        }
        
        return text
    }
    
    // MARK: - Temperature
    /// Writes the unit the way Apple's Weather does: "45°C", "113°F", and "318 K".
    static func temperatureText(_ temperature: TemperatureReading?, unit: FannySettings.TemperatureUnit, style: TemperatureStyle, locale: Locale = Locale.current) -> String {
        guard let temperature: TemperatureReading = temperature else { return missingText }
        
        let numberText: String = temperatureNumberText(temperature, unit: unit, style: style, locale: locale)
        let text: String
        
        switch (unit, style) {
        case (.kelvin, _):
            text = String(localized: "\(numberText) K", comment: "A temperature in kelvins, such as 318 K. The argument is a number.")
        case (_, .compact):
            text = String(localized: "\(numberText)°", comment: "A short temperature in the menu bar or widget, such as 45°, without the unit letter. The argument is a number.")
        case (.celsius, .full):
            text = String(localized: "\(numberText)°C", comment: "A temperature in degrees Celsius, such as 45.2°C. The argument is a number.")
        case (.fahrenheit, .full):
            text = String(localized: "\(numberText)°F", comment: "A temperature in degrees Fahrenheit, such as 113.4°F. The argument is a number.")
        }
        
        return text
    }
    
    /// Always names the unit, such as "45.2 degrees Celsius", for VoiceOver and Siri.
    static func spokenTemperatureText(_ temperature: TemperatureReading?, unit: FannySettings.TemperatureUnit, style: TemperatureStyle, locale: Locale = Locale.current) -> String {
        guard let temperature: TemperatureReading = temperature else { return spokenMissingText }
        
        let numberText: String = temperatureNumberText(temperature, unit: unit, style: style, locale: locale)
        let text: String
        
        switch unit {
        case .celsius:
            text = String(localized: "\(numberText) degrees Celsius", comment: "Spoken temperature for VoiceOver and Siri. The argument is a number such as 45.2.")
        case .fahrenheit:
            text = String(localized: "\(numberText) degrees Fahrenheit", comment: "Spoken temperature for VoiceOver and Siri. The argument is a number such as 113.4.")
        case .kelvin:
            text = String(localized: "\(numberText) kelvins", comment: "Spoken temperature in kelvins for VoiceOver and Siri. The argument is a number such as 318.2.")
        }
        
        return text
    }
    
    private static func temperatureNumberText(_ temperature: TemperatureReading, unit: FannySettings.TemperatureUnit, style: TemperatureStyle, locale: Locale) -> String {
        let fractionLength: Int = style == TemperatureStyle.full ? 1 : 0
        return numberText(temperature.value(in: unit), fractionLength: fractionLength, locale: locale)
    }
    
    // MARK: - Fan Limits
    /// A fan's minimum, maximum, and target, such as "Min 1350 · Max 5349 · Target 0 RPM", with only the limits it reports.
    /// - Returns: `nil` when the fan reports none.
    static func fanLimitsText(_ fan: FanReading, locale: Locale = Locale.current) -> SpokenText? {
        var parts: [String] = []
        var spokenParts: [String] = []
        
        if let minimumRPM: Double = fan.minimumRPM {
            let numberText: String = rpmNumberText(minimumRPM, locale: locale)
            parts.append(String(localized: "Min \(numberText)", comment: "Menu and widget: a fan's minimum speed, part of the line under each fan. The argument is a number such as 1350."))
            spokenParts.append(String(localized: "Minimum \(numberText)", comment: "Spoken by VoiceOver: a fan's minimum speed. The argument is a number such as 1350."))
        }
        
        if let maximumRPM: Double = fan.maximumRPM {
            let numberText: String = rpmNumberText(maximumRPM, locale: locale)
            parts.append(String(localized: "Max \(numberText)", comment: "Menu and widget: a fan's maximum speed, part of the line under each fan. The argument is a number such as 5349."))
            spokenParts.append(String(localized: "Maximum \(numberText)", comment: "Spoken by VoiceOver: a fan's maximum speed. The argument is a number such as 5349."))
        }
        
        if let targetRPM: Double = fan.targetRPM {
            let numberText: String = rpmNumberText(targetRPM, locale: locale)
            parts.append(String(localized: "Target \(numberText)", comment: "Menu and widget: the speed macOS is driving a fan toward, part of the line under each fan. The argument is a number such as 1350."))
            spokenParts.append(String(localized: "Target \(numberText)", comment: "Spoken by VoiceOver: the speed macOS is driving a fan toward. The argument is a number such as 1350."))
        }
        
        guard parts.isEmpty == false else { return nil }
        return SpokenText(text: rpmText(numberText: parts.joined(separator: " · ")), spokenText: spokenRPMText(numberText: spokenParts.joined(separator: ", ")))
    }
    
    // MARK: - Names
    static var cpuTitle: String {
        return String(localized: "CPU", comment: "Menu, tooltip, widget, and VoiceOver: label of the CPU temperature.")
    }
    
    static var gpuTitle: String {
        return String(localized: "GPU", comment: "Menu, tooltip, widget, and VoiceOver: label of the GPU temperature.")
    }
    
    /// The name the user typed for the fan, or its default name in the chosen style.
    static func fanName(id: Int, settings: FannySettings) -> String {
        return settings.customFanNames[id] ?? defaultFanName(id: id, style: settings.fanNameStyle)
    }
    
    /// macOS does not name its fans, so they are numbered from 1 or lettered from A.
    static func defaultFanName(id: Int, style: FannySettings.FanNameStyle) -> String {
        let name: String
        
        // Past Z, which no Mac reaches, letters fall back to numbers.
        if style == FannySettings.FanNameStyle.letters, let scalar: Unicode.Scalar = Unicode.Scalar(65 + id), id < 26 {
            let letter: String = String(Character(scalar))
            name = String(localized: "Fan \(letter)", comment: "Menu, tooltip, and widget: a fan's name when fans are lettered. The argument is a letter, starting at A.")
        }
        else {
            let number: Int = id + 1
            name = String(localized: "Fan \(number)", comment: "Menu, tooltip, and widget: a fan's name. The argument is its number, starting at 1.")
        }
        
        return name
    }
    
    // MARK: - Helpers
    private static var offText: String {
        return String(localized: "Off", comment: "The speed of a fan that is not spinning, shown in the menu, menu bar, and widget, and spoken by VoiceOver.")
    }
    
    private static var spokenMissingText: String {
        return String(localized: "Not available", comment: "Spoken by VoiceOver and Siri in place of a fan speed or temperature that could not be read or is hidden.")
    }
    
    /// Rounds half away from zero, like the monitor does when it decides whether a value visibly changed. Never groups thousands, so a fan speed reads 2410.
    private static func numberText(_ value: Double, fractionLength: Int, locale: Locale) -> String {
        let style: FloatingPointFormatStyle<Double> = FloatingPointFormatStyle<Double>(locale: locale).precision(.fractionLength(fractionLength)).rounded(rule: .toNearestOrAwayFromZero).grouping(.never)
        return value.formatted(style)
    }
}
