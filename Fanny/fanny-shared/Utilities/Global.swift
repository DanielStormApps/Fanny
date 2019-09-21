//
//  Global.swift
//  Fanny
//
//  Created by Daniel Storm on 9/15/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation

/// [Remove println() for release version iOS Swift](https://stackoverflow.com/a/38335438/2108547)
func print(_ item: @autoclosure () -> Any, separator: String = " ", terminator: String = "\n") {
    #if DEBUG
        Swift.print(item(), separator: separator, terminator: terminator)
    #endif
}
