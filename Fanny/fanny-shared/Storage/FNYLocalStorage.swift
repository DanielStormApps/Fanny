//
//  FNYLocalStorage.swift
//  Fanny
//
//  Created by Daniel Storm on 9/15/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation

class FNYLocalStorage {
    
    private static let sharedDefaultsSuiteName: String = "fanny-shared-defaults"
    private static let sharedDefaults: UserDefaults = UserDefaults(suiteName: FNYLocalStorage.sharedDefaultsSuiteName)!
    
    // MARK: - Fans
    static func save(fans: [Fan]) {
        save(numberOfFans: fans.count)
        for i in 0..<fans.count {
            sharedDefaults.set(fans[i].dictionaryRepresentation(), forKey: FNYStorageKey.fan(index: i).stringValue)
        }
    }
    
    static func fans() -> [Fan] {
        guard let numberOfFans = FNYLocalStorage.numberOfFans() else { return [] }
        var fans: [Fan] = []
        
        for i in 0..<numberOfFans {
            guard let dictionary = sharedDefaults.object(forKey: FNYStorageKey.fan(index: i).stringValue) as? [String: Any] else { continue }
            fans.append(Fan.from(dictionary: dictionary))
        }
        
        return fans
    }
    
    static func save(numberOfFans: Int) {
        sharedDefaults.set(numberOfFans, forKey: FNYStorageKey.numberOfFans.stringValue)
    }
    
    static func numberOfFans() -> Int? {
        return sharedDefaults.integer(forKey: FNYStorageKey.numberOfFans.stringValue)
    }
    
    // MARK: - CPU
    static func save(cpuTemperature: Temperature?) {
        sharedDefaults.set(cpuTemperature?.dictionaryRepresentation(), forKey: FNYStorageKey.cpu.stringValue)
    }
    
    static func cpuTemperature() -> Temperature? {
        guard let dictionary = sharedDefaults.object(forKey: FNYStorageKey.cpu.stringValue) as? [String: Any] else { return nil }
        return Temperature.from(dictionary: dictionary)
    }
    
    // MARK: - GPU
    static func save(gpuTemperature: Temperature?) {
        FNYLocalStorage.sharedDefaults.set(gpuTemperature?.dictionaryRepresentation(), forKey: FNYStorageKey.gpu.stringValue)
    }
    
    static func gpuTemperature() -> Temperature? {
        guard let dictionary = sharedDefaults.object(forKey: FNYStorageKey.gpu.stringValue) as? [String: Any] else { return nil }
        return Temperature.from(dictionary: dictionary)
    }
    
}

// MARK: - FNYStorageKey
private enum FNYStorageKey {
    
    case fan(index: Int)
    case numberOfFans
    case cpu
    case gpu
    
    var stringValue: String {
        switch self {
        case .fan(let index): return "FNYStorageKey_Fan\(index)"
        case .numberOfFans: return "FNYStorageKey_NumberOfFans"
        case .cpu: return "FNYStorageKey_CPU"
        case .gpu: return "FNYStorageKey_GPU"
        }
    }
    
}
