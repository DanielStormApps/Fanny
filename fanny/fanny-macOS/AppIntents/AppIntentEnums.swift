//
//  AppIntentEnums.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// The temperature units Shortcuts can choose, mirroring `FannySettings.TemperatureUnit`.
enum TemperatureUnitAppEnum: String, AppEnum {
    case celsius
    case fahrenheit
    case kelvin
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Temperature Unit")
    static var caseDisplayRepresentations: [TemperatureUnitAppEnum: DisplayRepresentation] = [.celsius: DisplayRepresentation(title: "Celsius (°C)"),
                                                                                              .fahrenheit: DisplayRepresentation(title: "Fahrenheit (°F)"),
                                                                                              .kelvin: DisplayRepresentation(title: "Kelvin (K)"),]
    
    var unit: FannySettings.TemperatureUnit {
        return FannySettings.TemperatureUnit(rawValue: rawValue) ?? FannySettings.TemperatureUnit.celsius
    }
}

/// The menu bar items Siri and Shortcuts can show or hide, mirroring `MenuBarLayout.ItemKind` without the numbered fans.
enum MenuBarItemAppEnum: String, AppEnum {
    case icon
    case fastestFan
    case cpu
    case gpu
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Menu Bar Item")
    static var caseDisplayRepresentations: [MenuBarItemAppEnum: DisplayRepresentation] = [.icon: DisplayRepresentation(title: "Fanny Icon"),
                                                                                          .fastestFan: DisplayRepresentation(title: "Fastest Fan"),
                                                                                          .cpu: DisplayRepresentation(title: "CPU Temperature"),
                                                                                          .gpu: DisplayRepresentation(title: "GPU Temperature"),]
    
    var kind: MenuBarLayout.ItemKind {
        let kind: MenuBarLayout.ItemKind
        
        switch self {
        case .icon:
            kind = MenuBarLayout.ItemKind.icon
        case .fastestFan:
            kind = MenuBarLayout.ItemKind.fastestFan
        case .cpu:
            kind = MenuBarLayout.ItemKind.cpu
        case .gpu:
            kind = MenuBarLayout.ItemKind.gpu
        }
        
        return kind
    }
}

/// The CPU sensor modes, mirroring `FannySettings.CPUSensorMode`.
enum CPUSensorAppEnum: String, AppEnum {
    case average
    case hottest
    case die
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "CPU Sensor")
    static var caseDisplayRepresentations: [CPUSensorAppEnum: DisplayRepresentation] = [.average: DisplayRepresentation(title: "Average"),
                                                                                         .hottest: DisplayRepresentation(title: "Hottest"),
                                                                                         .die: DisplayRepresentation(title: "Die"),]
    
    var mode: FannySettings.CPUSensorMode {
        return FannySettings.CPUSensorMode(rawValue: rawValue) ?? FannySettings.CPUSensorMode.average
    }
}

/// The GPU sensor modes, mirroring `FannySettings.GPUSensorMode`.
enum GPUSensorAppEnum: String, AppEnum {
    case average
    case hottest
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "GPU Sensor")
    static var caseDisplayRepresentations: [GPUSensorAppEnum: DisplayRepresentation] = [.average: DisplayRepresentation(title: "Average"),
                                                                                         .hottest: DisplayRepresentation(title: "Hottest"),]
    
    var mode: FannySettings.GPUSensorMode {
        return FannySettings.GPUSensorMode(rawValue: rawValue) ?? FannySettings.GPUSensorMode.average
    }
}
