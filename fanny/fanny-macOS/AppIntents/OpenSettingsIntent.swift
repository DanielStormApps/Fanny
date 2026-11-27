//
//  OpenSettingsIntent.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppIntents

/// Opens the Settings window.
struct OpenSettingsIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Open Fanny Settings"
    static var description: IntentDescription = IntentDescription("Open the Fanny settings window.", categoryName: "Settings")
    static var supportedModes: IntentModes = .foreground
    static var allowedExecutionTargets: IntentExecutionTargets = .main
    
    @MainActor
    func perform() async throws -> some IntentResult {
        AppBootstrap.shared.runIfNeeded()
        Log.info("📲 OpenSettingsIntent -> perform")
        
        AppIntentSupport.track("appIntentOpenSettings")
        SettingsWindowController.shared.show()
        return .result()
    }
}
