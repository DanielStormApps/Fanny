//
//  Analytics.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A shared instance class that manages analytics tracking.
final class Analytics {
    
    private var bridges: [AnalyticsBridge] = []
    
    /// Whether the user lets Fanny send analytics. On until they turn it off in Privacy Settings.
    private(set) var isEnabled: Bool = Storage.bool(forKey: .analyticsDisabled) == false
    
    // MARK: - Init
    private init() {}
    static let shared: Analytics = Analytics()
    
    func add(bridge: AnalyticsBridge) {
        bridges.append(bridge)
    }
    
    func track(event: AnalyticsEvent) {
        guard isEnabled else { return }
        
        for bridge in bridges {
            bridge.trackEvent(event)
        }
    }
    
    /// Sends `event` while analytics is still on, before turning it off and after turning it back on, so both changes are counted.
    func setEnabled(_ isEnabled: Bool, event: AnalyticsEvent) {
        guard isEnabled != self.isEnabled else { return }
        
        if isEnabled == false {
            track(event: event)
        }
        
        self.isEnabled = isEnabled
        Storage.save(isEnabled == false, forKey: .analyticsDisabled)
        
        for bridge in bridges {
            bridge.setEnabled(isEnabled)
        }
        
        Log.info("🔒 setAnalyticsEnabled -> isEnabled: \(isEnabled)")
        
        if isEnabled {
            track(event: event)
        }
    }
    
    /// Formats a string into a valid analytics event title using camelCase.
    /// Strips punctuation, emojis, and special characters. Converts spaces and dots to camelCase boundaries.
    /// - Note: Called internally by analytics bridges. Callers should pass raw strings.
    /// - Parameter input: The raw string to format (e.g., URL host, name, title)
    /// - Returns: A camelCase string suitable for analytics event titles
    static func formatEventTitle(_ input: String) -> String {
        let wordSeparators: CharacterSet = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "."))
        let allowedCharacters: CharacterSet = CharacterSet.alphanumerics.union(wordSeparators).union(CharacterSet(charactersIn: "_"))
        let stripped: String = input.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map { Character($0) }
            .map { String($0) }
            .joined()
        
        let words: [String] = stripped.components(separatedBy: wordSeparators).filter { $0.isEmpty == false }
        
        guard words.isEmpty == false else { return "" }
        
        var result: String = words[0].prefix(1).lowercased() + String(words[0].dropFirst())
        
        for word in words.dropFirst() {
            result = result + word.prefix(1).uppercased() + String(word.dropFirst())
        }
        
        return result
    }
}
