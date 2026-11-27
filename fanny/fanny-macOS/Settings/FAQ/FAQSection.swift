//
//  FAQSection.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A titled group of FAQ articles.
struct FAQSection: Codable, Hashable {
    
    let id: String
    let title: String
    let articles: [FAQArticle]
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FAQSection, rhs: FAQSection) -> Bool {
        return lhs.id == rhs.id
    }
}
