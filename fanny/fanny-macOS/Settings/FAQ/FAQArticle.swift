//
//  FAQArticle.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// Container for the FAQ articles JSON structure.
struct FAQArticlesContainer: Codable {
    let schemaVersion: Int
    let sections: [FAQSection]
}

// MARK: - FAQDestination
/// Where a navigation link in an article leads. An unknown value fails decoding, so a bad file is caught by the unit tests.
enum FAQDestination: String, Codable, CaseIterable {
    case settingsGeneral
    case settingsMenuBar
    case settingsFloatingWindow
    case settingsSensors
    case settingsAppearance
    case settingsPrivacy
    case contact
    case positive
}

// MARK: - FAQArticle
/// A single FAQ article with a title and content blocks.
struct FAQArticle: Codable, Hashable {
    
    let id: String
    let title: String
    let lastUpdated: String
    let symbol: String?
    let content: [FAQContentBlock]
    
    /// The JSON dates are Gregorian ISO dates, so they are read in a fixed calendar rather than the user's, which
    /// would read the year as Buddhist, Islamic, or Japanese era.
    var lastUpdatedDate: Date? {
        let inputFormatter: DateFormatter = DateFormatter()
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.calendar = Calendar(identifier: .gregorian)
        inputFormatter.dateFormat = "yyyy-MM-dd"
        return inputFormatter.date(from: lastUpdated)
    }
    
    /// The last updated date formatted for display (for example "11.07.2026").
    var lastUpdatedFormatted: String? {
        guard let date: Date = lastUpdatedDate else { return nil }
        
        let outputFormatter: DateFormatter = DateFormatter()
        outputFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yyyyMMdd", options: 0, locale: Locale.current) ?? "MM.dd.yyyy"
        
        return outputFormatter.string(from: date).replacingOccurrences(of: "/", with: ".")
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FAQArticle, rhs: FAQArticle) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - FAQContentBlock
/// Content block types for FAQ article content.
enum FAQContentBlock: Codable, Hashable {
    case paragraph(text: String)
    case bold(text: String)
    case numberedList(items: [String])
    case bulletList(items: [String])
    case navigationLink(text: String, destination: FAQDestination)
    case image(name: String)
    
    // MARK: - Coding Keys
    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case items
        case destination
        case name
    }
    
    private enum BlockType: String, Codable {
        case paragraph
        case bold
        case numberedList
        case bulletList
        case navigationLink
        case image
    }
    
    // MARK: - Decodable
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        let type: BlockType = try container.decode(BlockType.self, forKey: .type)
        
        switch type {
        case .paragraph:
            let text: String = try container.decode(String.self, forKey: .text)
            self = .paragraph(text: text)
        case .bold:
            let text: String = try container.decode(String.self, forKey: .text)
            self = .bold(text: text)
        case .numberedList:
            let items: [String] = try container.decode([String].self, forKey: .items)
            self = .numberedList(items: items)
        case .bulletList:
            let items: [String] = try container.decode([String].self, forKey: .items)
            self = .bulletList(items: items)
        case .navigationLink:
            let text: String = try container.decode(String.self, forKey: .text)
            let destination: FAQDestination = try container.decode(FAQDestination.self, forKey: .destination)
            self = .navigationLink(text: text, destination: destination)
        case .image:
            let name: String = try container.decode(String.self, forKey: .name)
            self = .image(name: name)
        }
    }
    
    // MARK: - Encodable
    func encode(to encoder: Encoder) throws {
        var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .paragraph(let text):
            try container.encode(BlockType.paragraph, forKey: .type)
            try container.encode(text, forKey: .text)
        case .bold(let text):
            try container.encode(BlockType.bold, forKey: .type)
            try container.encode(text, forKey: .text)
        case .numberedList(let items):
            try container.encode(BlockType.numberedList, forKey: .type)
            try container.encode(items, forKey: .items)
        case .bulletList(let items):
            try container.encode(BlockType.bulletList, forKey: .type)
            try container.encode(items, forKey: .items)
        case .navigationLink(let text, let destination):
            try container.encode(BlockType.navigationLink, forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encode(destination, forKey: .destination)
        case .image(let name):
            try container.encode(BlockType.image, forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }
}
