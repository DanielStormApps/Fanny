//
//  SettingsPane.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import SFSafeSymbols

/// A page of the Settings window, listed in its sidebar.
enum SettingsPane: String, CaseIterable {
    case general
    case sensors
    case menuBar
    case floatingWindow
    case appearance
    case privacy
    case faq
    case about
    
    var title: String {
        let title: String
        
        switch self {
        case .general:
            title = String(localized: "General", comment: "Settings sidebar and window title for the general preferences.")
        case .menuBar:
            title = String(localized: "Menu Bar", comment: "Settings sidebar and window title for what Fanny shows in the menu bar.")
        case .floatingWindow:
            title = String(localized: "Floating Window", comment: "Accessibility label of the floating window. Also the menu item and Settings pane that show or customize it.")
        case .sensors:
            title = String(localized: "Sensors", comment: "Settings sidebar and window title for the refresh interval, temperature unit, and sensor preferences.")
        case .appearance:
            title = String(localized: "Appearance", comment: "Settings sidebar and window title for the app theme preference.")
        case .privacy:
            title = String(localized: "Privacy", comment: "Settings sidebar and window title for the analytics and log preferences.")
        case .faq:
            title = String(localized: "FAQ", comment: "Settings sidebar and window title for the frequently asked questions.")
        case .about:
            title = String(localized: "About", comment: "Settings sidebar and window title for the app information page.")
        }
        
        return title
    }
    
    var symbol: SFSymbol {
        let symbol: SFSymbol
        
        switch self {
        case .general:
            symbol = .gearshape
        case .menuBar:
            symbol = .menubarRectangle
        case .floatingWindow:
            symbol = .pip
        case .sensors:
            symbol = .thermometerMedium
        case .appearance:
            symbol = .circleLefthalfFilled
        case .privacy:
            symbol = .handRaised
        case .faq:
            symbol = .questionmarkCircle
        case .about:
            symbol = .infoCircle
        }
        
        return symbol
    }
    
    // MARK: - View Controller
    func makeViewController() -> ViewController {
        let viewController: ViewController
        
        switch self {
        case .general:
            viewController = GeneralSettingsViewController()
        case .menuBar:
            viewController = MenuBarSettingsViewController()
        case .floatingWindow:
            viewController = FloatingWindowSettingsViewController()
        case .sensors:
            viewController = SensorSettingsViewController()
        case .appearance:
            viewController = AppearanceSettingsViewController()
        case .privacy:
            viewController = PrivacySettingsViewController()
        case .faq:
            viewController = FAQSettingsViewController()
        case .about:
            viewController = AboutSettingsViewController()
        }
        
        return viewController
    }
    
    // MARK: - Last Pane
    /// The pane saved the last time the user picked one, or General when nothing valid is saved.
    static func restored() -> SettingsPane {
        return SettingsPane(storedValue: Storage.string(forKey: .lastSettingsPane))
    }
    
    func saveAsLastPane() {
        Storage.save(rawValue, forKey: .lastSettingsPane)
    }
    
    init(storedValue: String?) {
        if let storedValue: String = storedValue, let pane: SettingsPane = SettingsPane(rawValue: storedValue) {
            self = pane
        }
        else {
            self = SettingsPane.general
        }
    }
}
