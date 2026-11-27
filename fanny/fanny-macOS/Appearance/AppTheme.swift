//
//  AppTheme.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

/// The user's in-app theme preference.
/// `system` defers to the Mac's appearance; `light` and `dark` force the corresponding style.
enum AppTheme: String, Codable, CaseIterable, Hashable {
    
    case system
    case light
    case dark
    
    /// The appearance to set on the app's windows for this theme.
    /// `system` maps to `nil` so the window inherits the Mac's appearance.
    var appearance: NSAppearance? {
        let appearance: NSAppearance?
        
        switch self {
        case .system:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: NSAppearance.Name.aqua)
        case .dark:
            appearance = NSAppearance(named: NSAppearance.Name.darkAqua)
        }
        
        return appearance
    }
    
    var title: String {
        let title: String
        
        switch self {
        case .system:
            title = String(localized: "System", comment: "App theme: system appearance option title")
        case .light:
            title = String(localized: "Light", comment: "App theme: light appearance option title")
        case .dark:
            title = String(localized: "Dark", comment: "App theme: dark appearance option title")
        }
        
        return title
    }
    
    /// Describes what selecting this option does.
    var caption: String {
        let caption: String
        
        switch self {
        case .system:
            caption = String(localized: "Match your Mac's appearance settings.", comment: "App theme: system appearance option caption")
        case .light:
            caption = String(localized: "Always use light mode, regardless of your Mac's appearance settings.", comment: "App theme: light appearance option caption")
        case .dark:
            caption = String(localized: "Always use dark mode, regardless of your Mac's appearance settings.", comment: "App theme: dark appearance option caption")
        }
        
        return caption
    }
    
    /// Analytics value used by the `appTheme` shared parameter.
    var analyticsValue: String {
        return rawValue
    }
}
