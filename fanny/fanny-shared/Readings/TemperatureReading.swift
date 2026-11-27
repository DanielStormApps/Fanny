//
//  TemperatureReading.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// One temperature, always stored in Celsius and converted only for display.
struct TemperatureReading: Codable, Equatable {
    var celsius: Double
    
    // MARK: - Conversion
    func value(in unit: FannySettings.TemperatureUnit) -> Double {
        let value: Double
        
        switch unit {
        case .celsius: value = celsius
        case .fahrenheit: value = celsius * 9.0 / 5.0 + 32.0
        case .kelvin: value = celsius + 273.15
        }
        
        return value
    }
}
