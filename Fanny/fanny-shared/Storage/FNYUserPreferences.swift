//
//  FNYUserPreferences.swift
//  Fanny
//
//  Created by Daniel Storm on 9/21/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation

typealias TemperatureUnitOption = (index: Int, title: String, suffix: String)

class FNYUserPreferences {
    
    static let temperatureUnitOptions: [TemperatureUnitOption] = {
        return [defaultTemperatureUnitOption,
                (1, "Fahrenheit (°F)", "°F"),
                (2, "Kelvin (°K)", "°K")]
    }()
    
    private static let defaultTemperatureUnitOption: TemperatureUnitOption = (0, "Celsius (°C)", "°C")
    
    private static let sharedDefaultsSuiteName: String = "fanny-shared-defaults"
    private static let sharedDefaults: UserDefaults = UserDefaults(suiteName: FNYUserPreferences.sharedDefaultsSuiteName)!
    
    // MARK: - Temperature
    static func save(temperatureUnitOption: TemperatureUnitOption) {
        sharedDefaults.set(temperatureUnitOption.index, forKey: FNYUserPreferencesKey.temperatureUnitOption.stringValue)
    }
    
    static func temperatureUnitOption() -> TemperatureUnitOption {
        let savedIndex = sharedDefaults.integer(forKey: FNYUserPreferencesKey.temperatureUnitOption.stringValue)
        return temperatureUnitOptions.first(where: { $0.index == savedIndex }) ?? defaultTemperatureUnitOption
    }
    
}

// MARK: - FNYUserPreferencesKey
private enum FNYUserPreferencesKey {
    
    case temperatureUnitOption
    
    var stringValue: String {
        switch self {
        case .temperatureUnitOption: return "FNYUserPreferencesKey_TemperatureUnitOption"
        }
    }
    
}
