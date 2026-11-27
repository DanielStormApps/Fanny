//
//  Config+Extensions.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

extension Config {
    
    // MARK: - Init
    init?(data: Data?) {
        guard
            let data: Data = data,
            let config: Config = try? JSONDecoder().decode(Config.self, from: data)
        else { return nil }
        
        self = config
    }
    
    // MARK: - Merge
    func merge(with otherConfig: Config?) -> Config? {
        guard let otherConfig: Config = otherConfig else { return nil }
        
        let encoder: JSONEncoder = JSONEncoder()
        
        guard
            let configData: Data = try? encoder.encode(self),
            let otherConfigData: Data = try? encoder.encode(otherConfig)
        else { return nil }
        
        guard
            let configDictionary: [String: Any] = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
            let otherConfigDictionary: [String: Any] = try? JSONSerialization.jsonObject(with: otherConfigData) as? [String: Any]
        else { return nil }
        
        var mergedConfigDictionary: [String: Any] = configDictionary
        mergedConfigDictionary.combine(with: otherConfigDictionary, ignoringNilValues: true)
        
        guard
            let mergedConfigData: Data = try? JSONSerialization.data(withJSONObject: mergedConfigDictionary),
            let mergedConfig: Config = try? JSONDecoder().decode(Config.self, from: mergedConfigData)
        else { return nil }
        
        return mergedConfig
    }
}
