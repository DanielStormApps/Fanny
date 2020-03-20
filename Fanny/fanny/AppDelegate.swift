//
//  AppDelegate.swift
//  Fanny
//
//  Created by Daniel Storm on 9/2/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    private var menuController: FNYMenuController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        menuController = FNYMenuController()
        
        FNYMonitor.shared.start()
        FNYMonitor.shared.delegate.add(menuController)
    }
    
}
