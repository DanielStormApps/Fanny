//
//  FNYMenuController.swift
//  Fanny
//
//  Created by Daniel Storm on 9/2/19.
//  Copyright © 2019 Daniel Storm. All rights reserved.
//

import Foundation
import Cocoa

class FNYMenuController {
    
    private let statusBar: FNYStatusBar = FNYStatusBar()
    
    // MARK: - Init
    init() {
        statusBar.menu.defaultItemDelegate = self
        updateMenu()
    }
    
    // MARK: - Update Menu
    @objc private func updateMenu() {
        statusBar.menu.update(fans: SMC.shared.fans(),
                              cpuTemperature: SMC.shared.cpuTemperature(),
                              gpuTemperature: SMC.shared.gpuTemperature())
    }
    
}

extension FNYMenuController: FNYMenuDefaultItemDelegate {
    
    // MARK: - FNYMenuDefaultItemDelegate
    func menu(_ menu: FNYMenu, didReceiveClickOnItem item: FNYMenu.Item) {
        switch item {
        case .moreApps:
            ()
            
        case .preferences:
            ()
            
        case .quit:
            ()
            
        }
    }
    
}
