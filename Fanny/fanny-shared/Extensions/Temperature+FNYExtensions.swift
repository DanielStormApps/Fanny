//
//  Temperature+FNYExtensions.swift
//  Fanny
//
//  Created by Daniel Storm on 9/21/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation

extension Temperature {

    func formattedTemperature(rounded: Bool = false) -> String {
        let temperature: Double
        let temperatureUnitOption: TemperatureUnitOption = FNYUserPreferences.temperatureUnitOption()
        
        switch temperatureUnitOption.index {
        case 0: temperature = self.celsius
        case 1: temperature = self.fahrenheit
        case 2: temperature = self.kelvin
        default: temperature = self.celsius
        }
        
        return rounded
            ? String(format: "%.0f\(temperatureUnitOption.suffix)", temperature.rounded())
            : String(format: "%.2f\(temperatureUnitOption.suffix)", temperature)
    }

    #if APP_EXTENSION
        //
    #else
        static func cpu() -> Temperature? {
            let cpuSensorOption = FNYUserPreferences.cpuSensorOption()
            return cpuSensorOption.index == 0 ? SMC.shared.cpuTemperatureAverage() : SMC.shared.cpuTemperature(key: cpuSensorOption.key)
        }

        static func gpu() -> Temperature? {
            let gpuSensorOption = FNYUserPreferences.gpuSensorOption()
            return gpuSensorOption.index == 0 ? SMC.shared.gpuTemperatureAverage() : SMC.shared.gpuTemperature(key: gpuSensorOption.key)
        }
    #endif
}
