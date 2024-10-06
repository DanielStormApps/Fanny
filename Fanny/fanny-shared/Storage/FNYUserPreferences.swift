//
//  FNYUserPreferences.swift
//  Fanny
//
//  Created by Daniel Storm on 9/21/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation

typealias MonitorRefreshTimeIntervalOption = (index: Int, title: String, timeInterval: TimeInterval)
typealias TemperatureUnitOption = (index: Int, title: String, suffix: String)
typealias MenuBarIconOption = (index: Int, title: String)
typealias CPUSensorOption = (index: Int, title: String, key: String?)
typealias GPUSensorOption = (index: Int, title: String, key: String?)
typealias FanSensorOption = (index: Int, title: String, key: String?)

class FNYUserPreferences {
    
    static let monitorRefreshTimeIntervalOptions: [MonitorRefreshTimeIntervalOption] = {
        return [defaultMonitorRefreshTimeIntervalOption,
                (1, "5 seconds", 5.0),
                (2, "10 seconds", 10.0),
                (3, "15 seconds", 15.0),
                (4, "30 seconds", 30.0),
                (5, "60 seconds", 60.0)]
    }()
    
    static let temperatureUnitOptions: [TemperatureUnitOption] = {
        return [defaultTemperatureUnitOption,
                (1, "Fahrenheit (°F)", "°F"),
                (2, "Kelvin (K)", " K")]
    }()
    
    static let menuBarIconOptions: [MenuBarIconOption] = {
        return [defaultMenuBarIconOption,
                (1, "CPU Temperature"),
                (2, "GPU Temperature"),
                (3, "Fastest Fan RPM")]
    }()

    static let cpuSensorOptions: [CPUSensorOption] = {
        return [defaultCPUSensorOption] + Sensor.CPU.allCases.map({ ($0.index + 1, $0.title, $0.key) })
    }()

    static let gpuSensorOptions: [GPUSensorOption] = {
        return [defaultGPUSensorOption] + Sensor.GPU.allCases.map({ ($0.index + 1, $0.title, $0.key) })
    }()
    
    private static let defaultMonitorRefreshTimeIntervalOption: MonitorRefreshTimeIntervalOption = (0, "3 seconds", 3.0)
    private static let defaultTemperatureUnitOption: TemperatureUnitOption = (0, "Celsius (°C)", "°C")
    private static let defaultMenuBarIconOption: MenuBarIconOption = (0, "Fanny Icon")
    private static let defaultCPUSensorOption: CPUSensorOption = (0, "Average", nil)
    private static let defaultGPUSensorOption: GPUSensorOption = (0, "Average", nil)

    private static let sharedDefaultsSuiteName: String = "fanny-shared-defaults"
    private static let sharedDefaults: UserDefaults = UserDefaults(suiteName: FNYUserPreferences.sharedDefaultsSuiteName)!
    
    // MARK: - Refresh Interval
    static func save(monitorRefreshTimeIntervalOption: MonitorRefreshTimeIntervalOption) {
        sharedDefaults.set(monitorRefreshTimeIntervalOption.index, forKey: FNYUserPreferencesKey.monitorRefreshTimeIntervalOption.stringValue)
    }
    
    static func monitorRefreshTimeIntervalOption() -> MonitorRefreshTimeIntervalOption {
        let savedIndex: Int = sharedDefaults.integer(forKey: FNYUserPreferencesKey.monitorRefreshTimeIntervalOption.stringValue)
        return monitorRefreshTimeIntervalOptions.first(where: { $0.index == savedIndex }) ?? defaultMonitorRefreshTimeIntervalOption
    }
    
    // MARK: - Temperature
    static func save(temperatureUnitOption: TemperatureUnitOption) {
        sharedDefaults.set(temperatureUnitOption.index, forKey: FNYUserPreferencesKey.temperatureUnitOption.stringValue)
    }
    
    static func temperatureUnitOption() -> TemperatureUnitOption {
        let savedIndex: Int = sharedDefaults.integer(forKey: FNYUserPreferencesKey.temperatureUnitOption.stringValue)
        return temperatureUnitOptions.first(where: { $0.index == savedIndex }) ?? defaultTemperatureUnitOption
    }
    
    // MARK: - Menu Bar Icon
    static func save(menuBarIconOption: MenuBarIconOption) {
        sharedDefaults.set(menuBarIconOption.index, forKey: FNYUserPreferencesKey.menuBarIconOption.stringValue)
    }
    
    static func menuBarIconOption() -> MenuBarIconOption {
        let savedIndex: Int = sharedDefaults.integer(forKey: FNYUserPreferencesKey.menuBarIconOption.stringValue)
        return menuBarIconOptions.first(where: { $0.index == savedIndex }) ?? defaultMenuBarIconOption
    }
    
    // MARK: - CPU Sensor
    static func save(cpuSensorOption: CPUSensorOption) {
        sharedDefaults.set(cpuSensorOption.index, forKey: FNYUserPreferencesKey.cpuSensorOption.stringValue)
    }

    static func cpuSensorOption() -> CPUSensorOption {
        let savedIndex: Int = sharedDefaults.integer(forKey: FNYUserPreferencesKey.cpuSensorOption.stringValue)
        return cpuSensorOptions.first(where: { $0.index == savedIndex }) ?? defaultCPUSensorOption
    }

    // MARK: - GPU Sensor
    static func save(gpuSensorOption: GPUSensorOption) {
        sharedDefaults.set(gpuSensorOption.index, forKey: FNYUserPreferencesKey.gpuSensorOption.stringValue)
    }

    static func gpuSensorOption() -> GPUSensorOption {
        let savedIndex: Int = sharedDefaults.integer(forKey: FNYUserPreferencesKey.gpuSensorOption.stringValue)
        return gpuSensorOptions.first(where: { $0.index == savedIndex }) ?? defaultGPUSensorOption
    }
    
}

// MARK: - FNYUserPreferencesKey
private enum FNYUserPreferencesKey {
    
    case monitorRefreshTimeIntervalOption
    case temperatureUnitOption
    case menuBarIconOption
    case cpuSensorOption
    case gpuSensorOption
    
    var stringValue: String {
        switch self {
        case .monitorRefreshTimeIntervalOption: return "FNYUserPreferencesKey_MonitorRefreshTimeIntervalOption"
        case .temperatureUnitOption: return "FNYUserPreferencesKey_TemperatureUnitOption"
        case .menuBarIconOption: return "FNYUserPreferencesKey_MenuBarIconOption"
        case .cpuSensorOption: return "FNYUserPreferencesKey_CPUSensorOption"
        case .gpuSensorOption: return "FNYUserPreferencesKey_GPUSensorOption"
        }
    }
    
}
