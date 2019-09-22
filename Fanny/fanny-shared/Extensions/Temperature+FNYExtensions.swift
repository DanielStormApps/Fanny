//
//  Temperature+FNYExtensions.swift
//  Fanny
//
//  Created by Daniel Storm on 9/21/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation

extension Temperature {

    func formattedTemperature() -> String {
        let temperature: Double
        let temperatureUnitOption: TemperatureUnitOption = FNYUserPreferences.temperatureUnitOption()
        
        switch temperatureUnitOption.index {
        case 0: temperature = self.celsius
        case 1: temperature = self.fahrenheit
        case 2: temperature = self.kelvin
        default: temperature = self.celsius
        }
        
        return String(format: "%.02f \(temperatureUnitOption.suffix)", temperature)
    }
    
}
