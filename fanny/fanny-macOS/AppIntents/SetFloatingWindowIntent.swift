//
//  SetFloatingWindowIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Shows or hides the floating window.
struct SetFloatingWindowIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Set Fanny Floating Window"
    static var description: IntentDescription = IntentDescription("Show or hide the floating window.", categoryName: "Floating Window")
    static var supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    @Parameter(title: "Visible")
    var isVisible: Bool
    
    static var parameterSummary: some ParameterSummary {
        Summary("Set the floating window to \(\.$isVisible)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 SetFloatingWindowIntent -> perform, isVisible: \(isVisible)")
        
        AppIntentSupport.track("appIntentSetFloatingWindow")
        let message: String = SetFloatingWindowIntent.apply(isVisible: isVisible)
        return .result(dialog: IntentDialog("\(message)"))
    }
    
    // MARK: - Apply
    /// Shared by the show and hide intents the App Shortcut phrases use.
    @MainActor
    static func apply(isVisible: Bool) -> String {
        FannySettingsManager.shared.update({ $0.showsFloatingWindow = isVisible })
        
        let message: String
        
        if isVisible {
            message = String(localized: "The floating window is showing.", comment: "Siri: spoken confirmation after showing the floating window")
        }
        else {
            message = String(localized: "The floating window is hidden.", comment: "Siri: spoken confirmation after hiding the floating window")
        }
        
        return message
    }
}
