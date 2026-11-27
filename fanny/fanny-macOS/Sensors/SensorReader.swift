//
//  SensorReader.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// Reads fans and temperatures through one SMC connection on its own serial queue, never the main thread.
final class SensorReader {
    
    /// The last live value of a temperature key, kept briefly when the key drops out.
    struct HeldTemperature: Equatable {
        let celsius: Double
        let date: Date
    }
    
    private struct FanLimits {
        let id: Int
        let minimumRPM: Double?
        let maximumRPM: Double?
    }
    
    /// One SMC key for the Developer Menu.
    struct DiagnosticReading: Equatable {
        let name: String
        /// `nil` when this Mac has no such key or the read failed.
        let value: Double?
        /// True when Fanny reads this key on this Mac for what the current settings show.
        let isUsed: Bool
    }
    
    /// Every fan, CPU, and GPU key Fanny can read, for the Developer Menu's tables.
    struct Diagnostics: Equatable {
        let fans: [DiagnosticReading]
        let cpu: [DiagnosticReading]
        let gpu: [DiagnosticReading]
    }
    
    private struct TemperatureKeys {
        let cpuDieKeys: [SMCKey]
        let cpuCoreKeys: [SMCKey]
        let gpuKeys: [SMCKey]
    }
    
    private let queue: DispatchQueue = DispatchQueue(label: "com.fannywidget.sensorReader", qos: DispatchQoS.utility)
    
    private var connection: SMCConnection?
    private var didLogConnectionFailure: Bool = false
    private var fanLimits: [FanLimits]?
    private var temperatureKeys: TemperatureKeys?
    private var keyInfos: [SMCKey: SMCKeyInfo] = [:]
    private var missingKeys: Set<SMCKey> = []
    private var heldTemperatures: [String: HeldTemperature] = [:]
    /// Every CPU and GPU temperature key this Mac lists, used or not, read once per connection for the Developer Menu.
    private var listedTemperatureKeyNames: [String]?
    
    /// Apple silicon Macs have at most two fans, so the Developer Menu always lists two, even on a Mac with fewer.
    private static let diagnosticFanCount: Int = 2
    
    /// Caps the fan loop when the SMC reports an implausible fan count, since `F<n>` key names use a single digit.
    private static let maximumFanCount: Int = 8
    
    private static let temperatureHoldTimeInterval: TimeInterval = 10.0
    
    // MARK: - Reading
    /// Reads on the reader queue and calls `completion` on the main thread.
    func readSnapshot(settings: FannySettings, completion: @escaping (ReadingsSnapshot) -> Void) {
        queue.async { [weak self] in
            guard let strongSelf: SensorReader = self else { return }
            let snapshot: ReadingsSnapshot = strongSelf.readSnapshot(settings: settings)
            
            DispatchQueue.main.async {
                completion(snapshot)
            }
        }
    }
    
    /// Closes the connection and forgets the fan limits and key list, so the next read rebuilds them, such as after wake.
    func reset() {
        queue.async { [weak self] in
            guard let strongSelf: SensorReader = self else { return }
            strongSelf.connection = nil
            strongSelf.didLogConnectionFailure = false
            strongSelf.fanLimits = nil
            strongSelf.temperatureKeys = nil
            strongSelf.keyInfos = [:]
            strongSelf.missingKeys = []
            strongSelf.heldTemperatures = [:]
            strongSelf.listedTemperatureKeyNames = nil
            Log.info("🌡️ SensorReader reset")
        }
    }
    
    private func readSnapshot(settings: FannySettings) -> ReadingsSnapshot {
        dispatchPrecondition(condition: DispatchPredicate.onQueue(queue))
        let date: Date = Date()
        guard let connection: SMCConnection = openConnectionIfNeeded() else { return ReadingsSnapshot.unavailable(at: date) }
        
        let limits: [FanLimits]? = fanLimits(connection: connection)
        let fans: [FanReading] = limits.map({ readFans(limits: $0, connection: connection) }) ?? []
        let fanStatus: ReadingsSnapshot.FanStatus
        
        if let limits: [FanLimits] = limits, limits.isEmpty {
            fanStatus = ReadingsSnapshot.FanStatus.noFans
        }
        else if fans.isEmpty {
            fanStatus = ReadingsSnapshot.FanStatus.unavailable
        }
        else {
            fanStatus = ReadingsSnapshot.FanStatus.fans
        }
        
        let keys: TemperatureKeys = temperatureKeys(connection: connection)
        let cpuTemperatures: [FannySettings.CPUSensorMode: TemperatureReading] = readCPUTemperatures(modes: settings.cpuModesToRead, keys: keys, connection: connection, date: date)
        let gpuTemperatures: [FannySettings.GPUSensorMode: TemperatureReading] = readGPUTemperatures(modes: settings.gpuModesToRead, keys: keys, connection: connection, date: date)
        
        return ReadingsSnapshot(capturedDate: date,
                                fanStatus: fanStatus,
                                fans: fans,
                                cpuTemperature: settings.showsCPUTemperature ? cpuTemperatures[settings.cpuSensorMode] : nil,
                                gpuTemperature: settings.showsGPUTemperature ? gpuTemperatures[settings.gpuSensorMode] : nil,
                                cpuTemperatures: cpuTemperatures,
                                gpuTemperatures: gpuTemperatures)
    }
    
    // MARK: - Developer Menu
    /// Reads every known fan, CPU, and GPU key on the reader queue and calls `completion` on the main thread.
    func readDiagnostics(settings: FannySettings, completion: @escaping (Diagnostics) -> Void) {
        queue.async { [weak self] in
            guard let strongSelf: SensorReader = self else { return }
            let diagnostics: Diagnostics = strongSelf.readDiagnostics(settings: settings)
            
            DispatchQueue.main.async {
                completion(diagnostics)
            }
        }
    }
    
    private func readDiagnostics(settings: FannySettings) -> Diagnostics {
        dispatchPrecondition(condition: DispatchPredicate.onQueue(queue))
        guard let connection: SMCConnection = openConnectionIfNeeded() else { return Diagnostics(fans: [], cpu: [], gpu: []) }
        
        let keys: TemperatureKeys = temperatureKeys(connection: connection)
        let usedNames: Set<String> = SensorReader.usedTemperatureKeyNames(cpuModes: settings.cpuModesToRead, gpuModes: settings.gpuModesToRead, cpuDieKeyNames: keys.cpuDieKeys.map({ $0.name }), cpuCoreKeyNames: keys.cpuCoreKeys.map({ $0.name }), gpuKeyNames: keys.gpuKeys.map({ $0.name }))
        let listedNames: [String] = listedTemperatureKeyNames(connection: connection)
        let cpuNames: Set<String> = Set(SensorCatalog.cpuKeyNames).union(listedNames.filter({ TemperatureSelector.isCPUDieKey($0) || TemperatureSelector.isCPUCoreKey($0) }))
        let gpuNames: Set<String> = Set(SensorCatalog.gpuKeyNames).union(listedNames.filter({ TemperatureSelector.isGPUKey($0) }))
        
        let fanCountValue: Double? = readValue(SMCKey.fanCount, connection: connection)
        var fans: [DiagnosticReading] = [DiagnosticReading(name: SMCKey.fanCount.name, value: fanCountValue, isUsed: fanCountValue != nil)]
        
        for index in 0..<max(Int(fanCountValue ?? 0.0), SensorReader.diagnosticFanCount) {
            for key in [SMCKey.fanCurrentSpeed(index), SMCKey.fanMinimumSpeed(index), SMCKey.fanMaximumSpeed(index), SMCKey.fanTargetSpeed(index)] {
                let value: Double? = readValue(key, connection: connection)
                fans.append(DiagnosticReading(name: key.name, value: value, isUsed: value != nil))
            }
        }
        
        return Diagnostics(fans: fans, cpu: diagnosticReadings(names: cpuNames, usedNames: usedNames, connection: connection), gpu: diagnosticReadings(names: gpuNames, usedNames: usedNames, connection: connection))
    }
    
    /// The temperature keys each refresh reads for the modes the settings show: core keys for Average, die keys for Die and Hottest, and every GPU key for either GPU mode.
    /// - Note: Average also reads the die keys on a refresh where no core key has a value, which this leaves out.
    static func usedTemperatureKeyNames(cpuModes: Set<FannySettings.CPUSensorMode>, gpuModes: Set<FannySettings.GPUSensorMode>, cpuDieKeyNames: [String], cpuCoreKeyNames: [String], gpuKeyNames: [String]) -> Set<String> {
        var names: Set<String> = []
        
        if cpuModes.contains(FannySettings.CPUSensorMode.average) {
            names.formUnion(cpuCoreKeyNames)
        }
        
        if cpuModes.contains(FannySettings.CPUSensorMode.die) || cpuModes.contains(FannySettings.CPUSensorMode.hottest) {
            names.formUnion(cpuDieKeyNames)
        }
        
        if gpuModes.isEmpty == false {
            names.formUnion(gpuKeyNames)
        }
        
        return names
    }
    
    /// Sorted by name, so each key keeps its row between reads.
    private func diagnosticReadings(names: Set<String>, usedNames: Set<String>, connection: SMCConnection) -> [DiagnosticReading] {
        return names.sorted().map({ name in
            return DiagnosticReading(name: name, value: readValue(SMCKey(name: name), connection: connection), isUsed: usedNames.contains(name))
        })
    }
    
    /// Lists every key once per connection, since the list never changes while the Mac is awake.
    private func listedTemperatureKeyNames(connection: SMCConnection) -> [String] {
        if let listedTemperatureKeyNames: [String] = listedTemperatureKeyNames {
            return listedTemperatureKeyNames
        }
        
        let keyCount: Int = Int(readValue(SMCKey.keyCount, connection: connection) ?? 0.0)
        var names: [String] = []
        
        for index in 0..<max(keyCount, 0) {
            guard let key: SMCKey = connection.key(at: UInt32(index)) else { continue }
            let name: String = key.name
            
            if TemperatureSelector.isCPUDieKey(name) || TemperatureSelector.isCPUCoreKey(name) || TemperatureSelector.isGPUKey(name) {
                names.append(name)
            }
        }
        
        listedTemperatureKeyNames = names
        return names
    }
    
    // MARK: - Connection
    private func openConnectionIfNeeded() -> SMCConnection? {
        if connection == nil {
            do {
                connection = try SMCConnection()
                didLogConnectionFailure = false
                Log.info("🌡️ SMC connection opened")
            }
            catch {
                if didLogConnectionFailure == false {
                    didLogConnectionFailure = true
                    Log.error("🌡️ SMC connection failed -> error: \(error)")
                }
            }
        }
        
        return connection
    }
    
    // MARK: - Fans
    /// The fan count and limits are read once per connection, and the current and target speeds on every read.
    private func readFans(limits: [FanLimits], connection: SMCConnection) -> [FanReading] {
        var fans: [FanReading] = []
        
        for limit in limits {
            guard let currentRPM: Double = readValue(SMCKey.fanCurrentSpeed(limit.id), connection: connection) else { continue }
            let targetRPM: Double? = readValue(SMCKey.fanTargetSpeed(limit.id), connection: connection)
            fans.append(FanReading(id: limit.id, currentRPM: max(currentRPM, 0.0), minimumRPM: limit.minimumRPM, maximumRPM: limit.maximumRPM, targetRPM: targetRPM))
        }
        
        return fans
    }
    
    /// - Returns: `nil` when the fan count could not be read, so the next read tries again.
    private func fanLimits(connection: SMCConnection) -> [FanLimits]? {
        if let fanLimits: [FanLimits] = fanLimits {
            return fanLimits
        }
        
        // A missing `FNum` key means the Mac has no fans, but a failed call is not cached as no fans.
        let fanCountValue: Double? = readValue(SMCKey.fanCount, connection: connection)
        guard fanCountValue != nil || missingKeys.contains(SMCKey.fanCount) else { return nil }
        
        let fanCount: Int = min(Int(fanCountValue ?? 0.0), SensorReader.maximumFanCount)
        var limits: [FanLimits] = []
        var didReadEveryLimit: Bool = true
        
        for index in 0..<max(fanCount, 0) {
            let minimumKey: SMCKey = SMCKey.fanMinimumSpeed(index)
            let maximumKey: SMCKey = SMCKey.fanMaximumSpeed(index)
            let minimumRPM: Double? = readValue(minimumKey, connection: connection)
            let maximumRPM: Double? = readValue(maximumKey, connection: connection)
            
            if (minimumRPM == nil && missingKeys.contains(minimumKey) == false) || (maximumRPM == nil && missingKeys.contains(maximumKey) == false) {
                didReadEveryLimit = false
            }
            
            limits.append(FanLimits(id: index, minimumRPM: minimumRPM, maximumRPM: maximumRPM))
        }
        
        // Limits from a failed call are used once and read again next time.
        if didReadEveryLimit {
            fanLimits = limits
            Log.info("🌀 SensorReader fans -> count: \(limits.count)")
        }
        
        return limits
    }
    
    // MARK: - Temperatures
    /// Reads each key set at most once, and only the sets the requested modes need, to keep SMC reads down.
    private func readCPUTemperatures(modes: Set<FannySettings.CPUSensorMode>, keys: TemperatureKeys, connection: SMCConnection, date: Date) -> [FannySettings.CPUSensorMode: TemperatureReading] {
        var values: [String: Double] = [:]
        var didReadDieKeys: Bool = false
        var didReadCoreKeys: Bool = false
        var temperatures: [FannySettings.CPUSensorMode: TemperatureReading] = [:]
        
        func readDieKeysIfNeeded() {
            guard didReadDieKeys == false else { return }
            didReadDieKeys = true
            values.merge(readTemperatures(keys.cpuDieKeys, connection: connection, date: date)) { (current, _) in current }
        }
        
        func readCoreKeysIfNeeded() {
            guard didReadCoreKeys == false else { return }
            didReadCoreKeys = true
            values.merge(readTemperatures(keys.cpuCoreKeys, connection: connection, date: date)) { (current, _) in current }
        }
        
        for mode in FannySettings.CPUSensorMode.allCases where modes.contains(mode) {
            switch mode {
            case .average:
                readCoreKeysIfNeeded()
            case .hottest, .die:
                readDieKeysIfNeeded()
            }
            
            var celsius: Double? = TemperatureSelector.cpuCelsius(values: values, mode: mode)
            
            if celsius == nil && mode != FannySettings.CPUSensorMode.die {
                readDieKeysIfNeeded()
                readCoreKeysIfNeeded()
                celsius = TemperatureSelector.cpuCelsius(values: values, mode: mode)
            }
            
            temperatures[mode] = celsius.map({ TemperatureReading(celsius: $0) })
        }
        
        return temperatures
    }
    
    private func readGPUTemperatures(modes: Set<FannySettings.GPUSensorMode>, keys: TemperatureKeys, connection: SMCConnection, date: Date) -> [FannySettings.GPUSensorMode: TemperatureReading] {
        guard modes.isEmpty == false else { return [:] }
        
        let values: [String: Double] = readTemperatures(keys.gpuKeys, connection: connection, date: date)
        var temperatures: [FannySettings.GPUSensorMode: TemperatureReading] = [:]
        
        for mode in modes {
            temperatures[mode] = TemperatureSelector.gpuCelsius(values: values, mode: mode).map({ TemperatureReading(celsius: $0) })
        }
        
        return temperatures
    }
    
    private func readTemperatures(_ keys: [SMCKey], connection: SMCConnection, date: Date) -> [String: Double] {
        var values: [String: Double?] = [:]
        
        for key in keys {
            values.updateValue(readValue(key, connection: connection), forKey: key.name)
        }
        
        return SensorReader.holdingTemperatures(values, heldTemperatures: &heldTemperatures, date: date)
    }
    
    /// Swaps a key that is not live for its last live value while that value is under 10 seconds old, and records every live value.
    static func holdingTemperatures(_ values: [String: Double?], heldTemperatures: inout [String: HeldTemperature], date: Date) -> [String: Double] {
        var resolvedValues: [String: Double] = [:]
        
        for (name, value) in values {
            if let celsius: Double = value, TemperatureSelector.isLive(celsius) {
                heldTemperatures[name] = HeldTemperature(celsius: celsius, date: date)
                resolvedValues[name] = celsius
            }
            else if let held: HeldTemperature = heldTemperatures[name], date.timeIntervalSince(held.date) <= temperatureHoldTimeInterval {
                resolvedValues[name] = held.celsius
            }
            else {
                heldTemperatures[name] = nil
                resolvedValues[name] = value
            }
        }
        
        return resolvedValues
    }
    
    /// Lists the `flt ` temperature keys once per connection, since the list never changes while the Mac is awake.
    private func temperatureKeys(connection: SMCConnection) -> TemperatureKeys {
        if let temperatureKeys: TemperatureKeys = temperatureKeys {
            return temperatureKeys
        }
        
        let keyCount: Int = Int(readValue(SMCKey.keyCount, connection: connection) ?? 0.0)
        var cpuDieKeys: [SMCKey] = []
        var cpuCoreKeys: [SMCKey] = []
        var gpuKeys: [SMCKey] = []
        
        for index in 0..<max(keyCount, 0) {
            guard let key: SMCKey = connection.key(at: UInt32(index)) else { continue }
            let name: String = key.name
            let isCPUDieKey: Bool = TemperatureSelector.isCPUDieKey(name)
            let isCPUCoreKey: Bool = TemperatureSelector.isCPUCoreKey(name)
            let isGPUKey: Bool = TemperatureSelector.isGPUKey(name)
            
            guard
                isCPUDieKey || isCPUCoreKey || isGPUKey,
                case SMCKeyLookup.found(let info) = connection.keyInfo(key),
                info.dataType == SMCDataType.float,
                info.dataSize == 4
            else { continue }
            
            keyInfos[key] = info
            
            if isCPUDieKey {
                cpuDieKeys.append(key)
            }
            else if isCPUCoreKey {
                cpuCoreKeys.append(key)
            }
            else {
                gpuKeys.append(key)
            }
        }
        
        // Some keys count only on the chips that use them, so the full list decides which to keep.
        let cpuCoreNames: Set<String> = Set(TemperatureSelector.cpuCoreKeyNames(cpuCoreKeys.map({ $0.name })))
        let gpuNames: Set<String> = Set(TemperatureSelector.gpuKeyNames(gpuKeys.map({ $0.name })))
        cpuCoreKeys = cpuCoreKeys.filter({ cpuCoreNames.contains($0.name) })
        gpuKeys = gpuKeys.filter({ gpuNames.contains($0.name) })
        
        let keys: TemperatureKeys = TemperatureKeys(cpuDieKeys: cpuDieKeys, cpuCoreKeys: cpuCoreKeys, gpuKeys: gpuKeys)
        temperatureKeys = keys
        Log.info("🌡️ SensorReader keys -> total: \(keyCount), cpuDie: \(cpuDieKeys.count), cpuCore: \(cpuCoreKeys.count), gpu: \(gpuKeys.count)")
        return keys
    }
    
    // MARK: - Helpers
    /// Keys the Mac does not have are remembered, so they cost no SMC call on later reads.
    private func readValue(_ key: SMCKey, connection: SMCConnection) -> Double? {
        guard missingKeys.contains(key) == false else { return nil }
        let info: SMCKeyInfo?
        
        if let cachedInfo: SMCKeyInfo = keyInfos[key] {
            info = cachedInfo
        }
        else {
            switch connection.keyInfo(key) {
            case SMCKeyLookup.found(let foundInfo):
                info = foundInfo
                keyInfos[key] = foundInfo
            case SMCKeyLookup.notFound:
                info = nil
                missingKeys.insert(key)
            case SMCKeyLookup.failed:
                info = nil
            }
        }
        
        guard let keyInfo: SMCKeyInfo = info else { return nil }
        return connection.value(key, info: keyInfo)?.doubleValue
    }
}
