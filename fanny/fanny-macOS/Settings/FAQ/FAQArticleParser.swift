//
//  FAQArticleParser.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// Parses FAQ sections from JSON.
final class FAQArticleParser {
    
    // MARK: - Parse
    /// Parses FAQ sections from a file path.
    /// - Returns: The sections, or an empty array if loading or decoding fails.
    func sections(filePath path: String) -> [FAQSection] {
        let fileURL: URL = URL(fileURLWithPath: path)
        guard let data: Data = try? Data(contentsOf: fileURL) else {
            Log.error("📖 sections -> failed to load data -> path: \(path)")
            return []
        }
        
        return sections(data: data)
    }
    
    /// Parses FAQ sections from a bundle resource, which resolves the active localization.
    /// - Returns: The sections, or an empty array if loading or decoding fails.
    func sections(resource: String, extension ext: String = "json") -> [FAQSection] {
        guard let path: String = Bundle.main.path(forResource: resource, ofType: ext) else {
            Log.error("📖 sections -> resource not found -> name: \(resource).\(ext)")
            return []
        }
        
        return sections(filePath: path)
    }
    
    /// Parses FAQ sections from JSON data.
    /// - Returns: The sections, or an empty array if decoding fails.
    func sections(data: Data) -> [FAQSection] {
        let sections: [FAQSection]
        
        do {
            let container: FAQArticlesContainer = try JSONDecoder().decode(FAQArticlesContainer.self, from: data)
            sections = container.sections
        }
        catch {
            Log.error("📖 sections -> failed to decode -> error: \(error.localizedDescription)")
            sections = []
        }
        
        return sections
    }
}
