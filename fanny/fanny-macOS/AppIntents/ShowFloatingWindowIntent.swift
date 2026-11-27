//
//  ShowFloatingWindowIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Shows the floating window, for its App Shortcut phrase.
struct ShowFloatingWindowIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Show Fanny Floating Window"
    static var description: IntentDescription = IntentDescription("Show the floating window.", categoryName: "Floating Window")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 ShowFloatingWindowIntent -> perform")
        
        AppIntentSupport.track("appIntentShowFloatingWindow")
        let message: String = SetFloatingWindowIntent.apply(isVisible: true)
        return .result(dialog: IntentDialog("\(message)"))
    }
}
