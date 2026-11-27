//
//  String+Extensions.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

extension String {
    
    /// Checks if the `String` matches the given regular expression.
    func matches(regex: String) -> Bool {
        let regexTest: NSPredicate = NSPredicate(format: "SELF MATCHES[c] %@", regex)
        return regexTest.evaluate(with: self)
    }
    
    /// The last path component of the receiver.
    var lastPathComponent: String {
        let value: NSString = self as NSString
        return value.lastPathComponent
    }
}
