//
//  FNYLauncher.swift
//  Fanny
//
//  Created by Daniel Storm on 9/21/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Cocoa

class FNYLauncher {
    
    private let parentApplicationBundleIdentifier: String = "com.fannywidget"
    private let parentApplicationURLScheme: URL = URL(string: "fannywidget://")!
    
    // MARK: - Init
    private init() {}
    static let shared: FNYLauncher = FNYLauncher()
    
    func launchParentApplicationIfNeeded() {
        guard !parentApplicationIsRunning() else { return }
        NSWorkspace.shared.open(parentApplicationURLScheme)
    }
    
    private func parentApplicationIsRunning() -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: parentApplicationBundleIdentifier).isEmpty
    }
    
}
