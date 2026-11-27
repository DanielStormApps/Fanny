//
//  AppThemeSettings.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// Persisted app theme and floating window glass settings.
struct AppThemeSettings: Codable {
    
    var selectedTheme: AppTheme
    var glassTintMatchesSystem: Bool
    /// From 0.0 to 1.0. Used only while `glassTintMatchesSystem` is off.
    var glassTintAmount: Double
    
    private static let defaultSelectedTheme: AppTheme = AppTheme.system
    private static let defaultGlassTintMatchesSystem: Bool = true
    private static let defaultGlassTintAmount: Double = 0.5
    
    static let glassTintAmountRange: ClosedRange<Double> = 0.0...1.0
    
    // MARK: - CodingKeys
    private enum CodingKeys: String, CodingKey {
        case selectedTheme
        case glassTintMatchesSystem
        case glassTintAmount
    }
    
    // MARK: - Init
    init() {
        selectedTheme = AppThemeSettings.defaultSelectedTheme
        glassTintMatchesSystem = AppThemeSettings.defaultGlassTintMatchesSystem
        glassTintAmount = AppThemeSettings.defaultGlassTintAmount
    }
    
    // MARK: - Decodable
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        selectedTheme = try container.decodeIfPresent(AppTheme.self, forKey: .selectedTheme) ?? AppThemeSettings.defaultSelectedTheme
        glassTintMatchesSystem = try container.decodeIfPresent(Bool.self, forKey: .glassTintMatchesSystem) ?? AppThemeSettings.defaultGlassTintMatchesSystem
        let decodedGlassTintAmount: Double = try container.decodeIfPresent(Double.self, forKey: .glassTintAmount) ?? AppThemeSettings.defaultGlassTintAmount
        glassTintAmount = min(max(decodedGlassTintAmount, AppThemeSettings.glassTintAmountRange.lowerBound), AppThemeSettings.glassTintAmountRange.upperBound)
    }
    
    // MARK: - Persistence
    static func load() -> AppThemeSettings {
        let settings: AppThemeSettings
        
        if let data: Data = Storage.data(forKey: .appThemeSettings),
           let loadedSettings: AppThemeSettings = try? JSONDecoder().decode(AppThemeSettings.self, from: data) {
            settings = loadedSettings
        }
        else {
            settings = AppThemeSettings()
        }
        
        return settings
    }
    
    func save() {
        guard let data: Data = try? JSONEncoder().encode(self) else { return }
        Storage.save(data, forKey: .appThemeSettings)
    }
}
