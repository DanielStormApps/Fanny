//
//  Bundle+Extensions.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

extension Bundle {
    
    static let version: String = {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }()
    
    static let buildNumber: String = {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    }()
}
