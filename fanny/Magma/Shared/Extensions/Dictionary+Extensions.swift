//
//  Dictionary+Extensions.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

extension Dictionary {
    
    /// Combines two dictionary objects by updating the values stored in the dictionary, or adding new key-value pairs if the key does not exist.
    mutating func combine(with otherDictionary: Dictionary, ignoringNilValues ignoreNilValues: Bool = false) {
        if ignoreNilValues {
            for (key, value) in otherDictionary where otherDictionary[key] != nil {
                self.updateValue(value, forKey: key)
            }
        }
        else {
            for (key, value) in otherDictionary {
                self.updateValue(value, forKey: key)
            }
        }
    }
}
