//
//  Sensor+FNYExtensions.swift
//  Fanny
//

import Foundation

extension SMC.Sensor.CPU {
    static func title(for key: SensorKey) -> String {
        switch key {
        case core_01:   return "Core 1"
        case core_02:   return "Core 2"
        case core_03:   return "Core 3"
        case core_04:   return "Core 4"
        case core_05:   return "Core 5"
        case core_06:   return "Core 6"
        case core_07:   return "Core 7"
        case core_08:   return "Core 8"
        case die:       return "Die"
        case diode:     return "Diode"
        case heatsink:  return "Heat Sink"
        case peci:      return "PECI"
        case proximity: return "Proximity"
        default:        return ""
        }
    }
}

extension SMC.Sensor.GPU {
    static func title(for key: SensorKey) -> String {
        switch key {
        case diode:     return "Diode"
        case heatsink:  return "Heat Sink"
        case peci:      return "PECI"
        case proximity: return "Proximity"
        default:        return ""
        }
    }
}
