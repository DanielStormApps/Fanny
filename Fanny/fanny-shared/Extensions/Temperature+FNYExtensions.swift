//
//  Temperature+FNYExtensions.swift
//  Fanny
//
//  Created by Daniel Storm on 9/21/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation

extension Temperature {

    func formattedTemperature(decimals: Int = 2, useSpaceDelimiter: Bool = true) -> String {
        let temperature: Double
        let temperatureUnitOption: TemperatureUnitOption = FNYUserPreferences.temperatureUnitOption()
        let formatSpecifier = ".0"+String(decimals)
        let delimiter: String = useSpaceDelimiter ? " " : ""
        
        switch temperatureUnitOption.index {
        case 0: temperature = self.celsius
        case 1: temperature = self.fahrenheit
        case 2: temperature = self.kelvin
        default: temperature = self.celsius
        }
        
        return String(format: "%\(formatSpecifier)f\(delimiter)\(temperatureUnitOption.suffix)", temperature)
    }
    
}
