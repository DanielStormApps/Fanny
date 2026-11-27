//
//  TemperatureSelector.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// Picks the CPU and GPU temperatures from SMC readings keyed by name, following each sensor mode.
enum TemperatureSelector {
    
    private static let cpuDieKey: String = "TCMb"
    private static let cpuHottestCoreKey: String = "TCMz"
    
    /// `Tm` is the CPU only on chips without `Te` keys, such as M5 Pro and Max, and memory everywhere else (see `cpuCoreKeyNames`).
    /// Other `T` families, such as most `Tf` keys, carry channels that look like temperatures but are not.
    private static let cpuCoreFamilies: [String] = ["Tp",
                                                    "Te",
                                                    "Tm",]
    
    private static let gpuFamilies: [String] = ["Tg",]
    
    /// The CPU cluster and GPU keys Stats reads on M3 chips, which it reports have no `Tp` or `Tg` keys, so they count only when those families are missing.
    private static let fallbackCPUCoreKeys: [String] = ["Tf04",
                                                        "Tf09",
                                                        "Tf0A",
                                                        "Tf0B",
                                                        "Tf0D",
                                                        "Tf0E",
                                                        "Tf44",
                                                        "Tf49",
                                                        "Tf4A",
                                                        "Tf4B",
                                                        "Tf4D",
                                                        "Tf4E",]
    
    private static let fallbackGPUKeys: [String] = ["Tf14",
                                                    "Tf18",
                                                    "Tf19",
                                                    "Tf1A",
                                                    "Tf24",
                                                    "Tf28",
                                                    "Tf29",
                                                    "Tf2A",]
    
    private static let minimumLiveCelsius: Double = 15.0
    private static let maximumLiveCelsius: Double = 120.0
    
    /// Max chips report exactly this while a sensor is clock gated at idle.
    private static let placeholderCelsius: Double = 40.0
    
    // MARK: - Keys
    static func isCPUDieKey(_ name: String) -> Bool {
        return name == cpuDieKey || name == cpuHottestCoreKey
    }
    
    static func isCPUCoreKey(_ name: String) -> Bool {
        return isKey(name, inFamilies: cpuCoreFamilies) || fallbackCPUCoreKeys.contains(name)
    }
    
    static func isGPUKey(_ name: String) -> Bool {
        return isKey(name, inFamilies: gpuFamilies) || fallbackGPUKeys.contains(name)
    }
    
    /// Keeps the CPU keys this Mac's chip uses: `Tm` only without `Te` keys, and the `Tf` fallbacks only without `Tp` keys.
    /// - Note: Decided from every key the Mac lists, live or not, so cores powered down at idle never change the choice.
    static func cpuCoreKeyNames(_ names: [String]) -> [String] {
        let hasEfficiencyKeys: Bool = names.contains(where: { $0.hasPrefix("Te") })
        let hasPerformanceKeys: Bool = names.contains(where: { $0.hasPrefix("Tp") })
        
        return names.filter({ name in
            let isKept: Bool
            
            if name.hasPrefix("Tm") {
                isKept = hasEfficiencyKeys == false
            }
            else if fallbackCPUCoreKeys.contains(name) {
                isKept = hasPerformanceKeys == false
            }
            else {
                isKept = true
            }
            
            return isKept
        })
    }
    
    /// Keeps the `Tf` fallbacks only on a Mac without `Tg` keys.
    static func gpuKeyNames(_ names: [String]) -> [String] {
        let hasGPUKeys: Bool = names.contains(where: { $0.hasPrefix("Tg") })
        return names.filter({ fallbackGPUKeys.contains($0) == false || hasGPUKeys == false })
    }
    
    // MARK: - Liveness
    /// Powered down cores read sentinels such as 0.0 or 6.7, so only plausible values count.
    static func isLive(_ celsius: Double) -> Bool {
        return celsius.isFinite && celsius >= minimumLiveCelsius && celsius <= maximumLiveCelsius && celsius != placeholderCelsius
    }
    
    // MARK: - CPU
    static func cpuCelsius(values: [String: Double], mode: FannySettings.CPUSensorMode) -> Double? {
        let celsius: Double?
        
        switch mode {
        case .average:
            // A Mac whose cores all read as powered down still shows its die sensor rather than a dash.
            celsius = averageCoreCelsius(values) ?? liveValue(values, key: cpuDieKey) ?? liveValue(values, key: cpuHottestCoreKey) ?? coldDieValue(values)
        case .hottest:
            celsius = liveValue(values, key: cpuHottestCoreKey) ?? hottestFamilyValues(values, isIncluded: isCPUCoreKey).max()
        case .die:
            celsius = liveValue(values, key: cpuDieKey) ?? coldDieValue(values)
        }
        
        return celsius
    }
    
    // MARK: - GPU
    /// Without a live GPU key the GPU reads as missing, rather than borrowing another sensor.
    static func gpuCelsius(values: [String: Double], mode: FannySettings.GPUSensorMode) -> Double? {
        let hottestValues: [Double] = hottestFamilyValues(values, isIncluded: isGPUKey)
        let celsius: Double?
        
        switch mode {
        case .average:
            celsius = average(hottestValues)
        case .hottest:
            celsius = hottestValues.max()
        }
        
        return celsius
    }
    
    // MARK: - Helpers
    private static func isKey(_ name: String, inFamilies families: [String]) -> Bool {
        return name.count == 4 && families.contains(String(name.prefix(2)))
    }
    
    /// The die sensor stays powered, so a reading under the live range is a genuinely cold Mac, not a powered down core, and shows instead of a dash.
    private static func coldDieValue(_ values: [String: Double]) -> Double? {
        guard
            let celsius: Double = values[cpuDieKey],
            celsius.isFinite,
            celsius > 0.0,
            celsius < minimumLiveCelsius
        else { return nil }
        
        return celsius
    }
    
    private static func liveValue(_ values: [String: Double], key: String) -> Double? {
        guard
            let celsius: Double = values[key],
            isLive(celsius)
        else { return nil }
        
        return celsius
    }
    
    private static func averageCoreCelsius(_ values: [String: Double]) -> Double? {
        return average(hottestFamilyValues(values, isIncluded: isCPUCoreKey))
    }
    
    /// The hottest live key in each three character family, because many keys are offset copies of one sensor and would count twice.
    private static func hottestFamilyValues(_ values: [String: Double], isIncluded: (String) -> Bool) -> [Double] {
        var hottestByFamily: [String: Double] = [:]
        
        for (name, celsius) in values where isIncluded(name) && isLive(celsius) {
            let family: String = String(name.prefix(3))
            hottestByFamily[family] = max(hottestByFamily[family] ?? celsius, celsius)
        }
        
        return hottestByFamily.keys.sorted().compactMap({ hottestByFamily[$0] })
    }
    
    private static func average(_ values: [Double]) -> Double? {
        guard values.isEmpty == false else { return nil }
        return values.reduce(0.0, +) / Double(values.count)
    }
}
