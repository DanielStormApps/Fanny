//
//  Bundle+FNYExtensions.swift
//  Fanny
//
//  Created by Daniel Storm on 9/21/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation

extension Bundle {
    
    static var appVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
    
}
