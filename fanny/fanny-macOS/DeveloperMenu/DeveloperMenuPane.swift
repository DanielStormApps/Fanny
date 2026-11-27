//
//  DeveloperMenuPane.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/25/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import SFSafeSymbols

/// A page of the Developer Menu window, listed in its sidebar.
enum DeveloperMenuPane: CaseIterable {
    case logs
    case sensors
    
    var title: String {
        let title: String
        
        switch self {
        case .logs:
            title = String(localized: "Logs", comment: "Developer Menu: sidebar item and pane title for the saved log files.")
        case .sensors:
            title = String(localized: "Sensors", comment: "Developer Menu: sidebar item and pane title for the raw sensor readings.")
        }
        
        return title
    }
    
    var symbol: SFSymbol {
        let symbol: SFSymbol
        
        switch self {
        case .logs:
            symbol = .textDocument
        case .sensors:
            symbol = .thermometerMedium
        }
        
        return symbol
    }
    
    // MARK: - View Controller
    func makeViewController() -> ViewController {
        let viewController: ViewController
        
        switch self {
        case .logs:
            viewController = DeveloperLogsViewController()
        case .sensors:
            viewController = DeveloperSensorsViewController()
        }
        
        return viewController
    }
}
