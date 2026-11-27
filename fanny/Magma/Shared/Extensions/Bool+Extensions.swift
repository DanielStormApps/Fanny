//
//  Bool+Extensions.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

extension Bool {
    
    /// `"true"` or `"false"`, for analytics parameters that take string values.
    var stringValue: String {
        return self == true ? "true" : "false"
    }
}
