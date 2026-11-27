//
//  FannySettings.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// The user's readings, menu bar, and floating window preferences, saved as one value.
struct FannySettings: Codable, Equatable {
    
    /// How a fan is named when the user has not typed a name for it.
    enum FanNameStyle: String, Codable, CaseIterable {
        case numbers
        case letters
    }
    
    enum TemperatureUnit: String, Codable, CaseIterable {
        case celsius
        case fahrenheit
        case kelvin
    }
    
    /// A coding key in the snapshot's temperature lists, so they save as JSON objects.
    enum CPUSensorMode: String, Codable, CaseIterable, CodingKeyRepresentable {
        case average
        case hottest
        case die
    }
    
    enum GPUSensorMode: String, Codable, CaseIterable, CodingKeyRepresentable {
        case average
        case hottest
    }
    
    var refreshTimeInterval: TimeInterval
    var temperatureUnit: TemperatureUnit
    var menuBarLayout: MenuBarLayout
    var fanNameStyle: FanNameStyle
    /// The names the user typed, by SMC fan index. A fan without one uses `fanNameStyle`.
    var customFanNames: [Int: String]
    var cpuSensorMode: CPUSensorMode
    var gpuSensorMode: GPUSensorMode
    var showsCPUTemperature: Bool
    var showsGPUTemperature: Bool
    var checksForUpdatesAutomatically: Bool
    var showsFloatingWindow: Bool
    var floatingWindowLayout: FloatingWindowLayout
    
    /// Long enough for a nickname or an emoji, short enough to keep the menu bar item from growing too wide. The widget truncates a name that does not fit.
    static let fanNameMaxLength: Int = 30
    
    /// Whole seconds, typed or stepped in the Sensors pane.
    static let refreshSecondsRange: ClosedRange<Int> = 1...60
    
    private static let defaultRefreshTimeInterval: TimeInterval = 4.0
    /// Apple names no official CPU temperature, so the default is the core average most Mac monitoring apps show.
    private static let defaultCPUSensorMode: CPUSensorMode = CPUSensorMode.average
    private static let defaultGPUSensorMode: GPUSensorMode = GPUSensorMode.average
    private static let defaultShowsCPUTemperature: Bool = true
    private static let defaultShowsGPUTemperature: Bool = true
    private static let defaultChecksForUpdatesAutomatically: Bool = true
    private static let defaultShowsFloatingWindow: Bool = false
    
    // MARK: - Init
    init(locale: Locale = Locale.current) {
        refreshTimeInterval = FannySettings.defaultRefreshTimeInterval
        temperatureUnit = FannySettings.defaultTemperatureUnit(locale: locale)
        menuBarLayout = MenuBarLayout()
        fanNameStyle = FanNameStyle.numbers
        customFanNames = [:]
        cpuSensorMode = FannySettings.defaultCPUSensorMode
        gpuSensorMode = FannySettings.defaultGPUSensorMode
        showsCPUTemperature = FannySettings.defaultShowsCPUTemperature
        showsGPUTemperature = FannySettings.defaultShowsGPUTemperature
        checksForUpdatesAutomatically = FannySettings.defaultChecksForUpdatesAutomatically
        showsFloatingWindow = FannySettings.defaultShowsFloatingWindow
        floatingWindowLayout = FloatingWindowLayout()
    }
    
    /// Whole seconds inside `refreshSecondsRange`, so a value saved by another version or set by Shortcuts always fits.
    static func clampedRefreshTimeInterval(_ timeInterval: TimeInterval) -> TimeInterval {
        let seconds: Double = timeInterval.isFinite ? timeInterval.rounded() : FannySettings.defaultRefreshTimeInterval
        // Clamped as a Double, since converting a huge saved value to Int would crash.
        return min(max(seconds, Double(FannySettings.refreshSecondsRange.lowerBound)), Double(FannySettings.refreshSecondsRange.upperBound))
    }
    
    /// Trims the name and cuts it to `fanNameMaxLength` characters, counting an emoji as one.
    /// - Returns: `nil` for an empty name, so the fan goes back to its default name.
    static func cleanedFanName(_ name: String) -> String? {
        let trimmedName: String = String(name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).prefix(FannySettings.fanNameMaxLength))
        return trimmedName.isEmpty ? nil : trimmedName
    }
    
    /// Fahrenheit for regions that measure in US units, otherwise Celsius.
    static func defaultTemperatureUnit(locale: Locale) -> TemperatureUnit {
        return locale.measurementSystem == Locale.MeasurementSystem.us ? TemperatureUnit.fahrenheit : TemperatureUnit.celsius
    }
    
    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case refreshTimeInterval
        case temperatureUnit
        case menuBarLayout
        case fanNameStyle
        case customFanNames
        case cpuSensorMode
        case gpuSensorMode
        case showsCPUTemperature
        case showsGPUTemperature
        case checksForUpdatesAutomatically
        case showsFloatingWindow
        case floatingWindowLayout
    }
    
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        let decodedRefreshTimeInterval: TimeInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .refreshTimeInterval) ?? FannySettings.defaultRefreshTimeInterval
        refreshTimeInterval = FannySettings.clampedRefreshTimeInterval(decodedRefreshTimeInterval)
        temperatureUnit = (try? container.decodeIfPresent(TemperatureUnit.self, forKey: .temperatureUnit)) ?? FannySettings.defaultTemperatureUnit(locale: Locale.current)
        menuBarLayout = try container.decodeIfPresent(MenuBarLayout.self, forKey: .menuBarLayout) ?? MenuBarLayout()
        fanNameStyle = (try? container.decodeIfPresent(FanNameStyle.self, forKey: .fanNameStyle)) ?? FanNameStyle.numbers
        // Cleaned again on load, so a name saved by another version or edited by hand never breaks the layout.
        let decodedFanNames: [Int: String] = (try? container.decodeIfPresent([Int: String].self, forKey: .customFanNames)) ?? [:]
        customFanNames = decodedFanNames.compactMapValues({ FannySettings.cleanedFanName($0) })
        // An unknown saved mode falls back to the default instead of failing every setting.
        cpuSensorMode = (try? container.decodeIfPresent(CPUSensorMode.self, forKey: .cpuSensorMode)) ?? FannySettings.defaultCPUSensorMode
        gpuSensorMode = (try? container.decodeIfPresent(GPUSensorMode.self, forKey: .gpuSensorMode)) ?? FannySettings.defaultGPUSensorMode
        showsCPUTemperature = try container.decodeIfPresent(Bool.self, forKey: .showsCPUTemperature) ?? FannySettings.defaultShowsCPUTemperature
        showsGPUTemperature = try container.decodeIfPresent(Bool.self, forKey: .showsGPUTemperature) ?? FannySettings.defaultShowsGPUTemperature
        checksForUpdatesAutomatically = try container.decodeIfPresent(Bool.self, forKey: .checksForUpdatesAutomatically) ?? FannySettings.defaultChecksForUpdatesAutomatically
        showsFloatingWindow = try container.decodeIfPresent(Bool.self, forKey: .showsFloatingWindow) ?? FannySettings.defaultShowsFloatingWindow
        floatingWindowLayout = try container.decodeIfPresent(FloatingWindowLayout.self, forKey: .floatingWindowLayout) ?? FloatingWindowLayout()
    }
    
    // MARK: - Reading
    /// The CPU modes to read: the one the menu shows, and any a shown floating window card shows. None when the CPU temperature is turned off.
    var cpuModesToRead: Set<CPUSensorMode> {
        guard showsCPUTemperature else { return [] }
        
        var modes: Set<CPUSensorMode> = [cpuSensorMode]
        
        for stat in floatingWindowStats {
            if let mode: CPUSensorMode = stat.cpuSensorMode(selectedMode: cpuSensorMode) {
                modes.insert(mode)
            }
        }
        
        return modes
    }
    
    /// The GPU modes to read: the one the menu shows, and any a shown floating window card shows. None when the GPU temperature is turned off.
    var gpuModesToRead: Set<GPUSensorMode> {
        guard showsGPUTemperature else { return [] }
        
        var modes: Set<GPUSensorMode> = [gpuSensorMode]
        
        for stat in floatingWindowStats {
            if let mode: GPUSensorMode = stat.gpuSensorMode(selectedMode: gpuSensorMode) {
                modes.insert(mode)
            }
        }
        
        return modes
    }
    
    /// Temperature stats do not depend on the fans, so no fan list is needed here.
    private var floatingWindowStats: Set<FloatingWindowLayout.Stat> {
        guard showsFloatingWindow else { return [] }
        return floatingWindowLayout.visibleStats(fanIDs: [])
    }
    
    // MARK: - Storage
    static func load() -> FannySettings {
        let settings: FannySettings
        
        if let data: Data = Storage.data(forKey: .fannySettings) {
            do {
                settings = try JSONDecoder().decode(FannySettings.self, from: data)
            }
            catch {
                Log.error("💾 FannySettings load -> error: \(error.localizedDescription)")
                settings = FannySettings()
            }
        }
        else {
            settings = FannySettings()
        }
        
        return settings
    }
    
    /// - Returns: `false` when the settings could not be encoded, so nothing was saved.
    @discardableResult
    func save() -> Bool {
        let didSave: Bool
        
        do {
            let data: Data = try JSONEncoder().encode(self)
            Storage.save(data, forKey: .fannySettings)
            didSave = true
        }
        catch {
            Log.error("💾 FannySettings save -> error: \(error.localizedDescription)")
            didSave = false
        }
        
        return didSave
    }
}
