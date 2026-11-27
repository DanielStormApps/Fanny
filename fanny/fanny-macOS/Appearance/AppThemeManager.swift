//
//  AppThemeManager.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

/// Singleton that owns the app theme and glass tint, and applies them to the app's windows.
/// - Note: The theme is set per window, so the status item and its menu keep following the Mac's appearance.
final class AppThemeManager {
    
    private var settings: AppThemeSettings
    private let windows: NSHashTable<NSWindow> = NSHashTable<NSWindow>.weakObjects()
    
    /// AppKit reads the glass tint from this default. Set in the app's own domain, it overrides the system value for this process only.
    private static let glassTintAmountDefaultsKey: String = "NSGlassTintAmount"
    /// Tells glass already on screen to read the tint again.
    private static let glassTintDidChangeNotification: Notification.Name = Notification.Name("NSGlassEffectDiffusionDidChangeNotification")
    
    var selectedTheme: AppTheme {
        return settings.selectedTheme
    }
    
    var glassTintMatchesSystem: Bool {
        return settings.glassTintMatchesSystem
    }
    
    var glassTintAmount: Double {
        return settings.glassTintAmount
    }
    
    /// Analytics value for the `appTheme` shared parameter.
    var themeAnalyticsValue: String {
        return selectedTheme.analyticsValue
    }
    
    /// Analytics value for the `glassTint` shared parameter: `system`, or the amount from 0.0 to 1.0.
    var glassTintAnalyticsValue: String {
        return glassTintMatchesSystem ? "system" : String(format: "%.1f", glassTintAmount)
    }
    
    // MARK: - Init
    private init() {
        settings = AppThemeSettings.load()
    }
    static let shared: AppThemeManager = AppThemeManager()
    
    // MARK: - Theme
    /// Applies the theme to the window now and again whenever the theme changes.
    func register(_ window: NSWindow) {
        windows.add(window)
        apply(to: window)
    }
    
    private func apply(to window: NSWindow) {
        window.appearance = settings.selectedTheme.appearance
    }
    
    func setTheme(_ theme: AppTheme) {
        guard theme != settings.selectedTheme else { return }
        
        Log.info("🎨 setTheme -> \(theme.rawValue)")
        settings.selectedTheme = theme
        settings.save()
        
        for window in windows.allObjects {
            apply(to: window)
        }
    }
    
    // MARK: - Glass Tint
    func setGlassTintMatchesSystem(_ matchesSystem: Bool) {
        guard matchesSystem != settings.glassTintMatchesSystem else { return }
        
        Log.info("🎨 setGlassTintMatchesSystem -> \(matchesSystem)")
        settings.glassTintMatchesSystem = matchesSystem
        settings.save()
        applyGlassTint()
    }
    
    func setGlassTintAmount(_ amount: Double) {
        let clampedAmount: Double = min(max(amount, AppThemeSettings.glassTintAmountRange.lowerBound), AppThemeSettings.glassTintAmountRange.upperBound)
        guard clampedAmount != settings.glassTintAmount else { return }
        
        Log.debug("🎨 setGlassTintAmount -> \(clampedAmount)")
        settings.glassTintAmount = clampedAmount
        settings.save()
        applyGlassTint()
    }
    
    /// Sets or clears the app's tint override and refreshes glass already on screen. Call at launch, before any glass is built.
    func applyGlassTint() {
        if settings.glassTintMatchesSystem {
            UserDefaults.standard.removeObject(forKey: AppThemeManager.glassTintAmountDefaultsKey)
        }
        else {
            UserDefaults.standard.set(settings.glassTintAmount, forKey: AppThemeManager.glassTintAmountDefaultsKey)
        }
        
        NotificationCenter.default.post(name: AppThemeManager.glassTintDidChangeNotification, object: nil)
    }
}
