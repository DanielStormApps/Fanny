//
//  ApplicationDelegate.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A listener for application life cycle events.
protocol ApplicationDelegate: AnyObject {
    
    func applicationDidFinishLaunching()
    func applicationWillBecomeActive()
    func applicationDidBecomeActive()
    func applicationWillResignActive()
    func applicationDidResignActive()
    func applicationWillTerminate()
}

extension ApplicationDelegate {
    
    func applicationDidFinishLaunching() { }
    func applicationWillBecomeActive() { }
    func applicationDidBecomeActive() { }
    func applicationWillResignActive() { }
    func applicationDidResignActive() { }
    func applicationWillTerminate() { }
}
