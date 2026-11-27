//
//  HideFloatingWindowIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Hides the floating window, for its App Shortcut phrase.
struct HideFloatingWindowIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Hide Fanny Floating Window"
    static var description: IntentDescription = IntentDescription("Hide the floating window.", categoryName: "Floating Window")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 HideFloatingWindowIntent -> perform")
        
        AppIntentSupport.track("appIntentHideFloatingWindow")
        let message: String = SetFloatingWindowIntent.apply(isVisible: false)
        return .result(dialog: IntentDialog("\(message)"))
    }
}
