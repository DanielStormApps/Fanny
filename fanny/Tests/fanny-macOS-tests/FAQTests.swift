//
//  FAQTests.swift
//  fanny-macOS-tests
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import XCTest
@testable import Fanny

/// Tests the FAQ model, parser, and the bundled English articles.
final class FAQTests: XCTestCase {
    
    private let parser: FAQArticleParser = FAQArticleParser()
    
    private var bundledArticles: [FAQArticle] {
        return parser.sections(resource: "faq-articles").flatMap({ $0.articles })
    }
    
    func testParserDecodesTheBundledFile() {
        let sections: [FAQSection] = parser.sections(resource: "faq-articles")
        XCTAssertFalse(sections.isEmpty)
        XCTAssertFalse(bundledArticles.isEmpty)
    }
    
    func testBundledArticleIDsAreUnique() {
        let ids: [String] = bundledArticles.map({ $0.id })
        XCTAssertEqual(ids.count, Set(ids).count)
    }
    
    func testBundledSectionIDsAreUnique() {
        let ids: [String] = parser.sections(resource: "faq-articles").map({ $0.id })
        XCTAssertEqual(ids.count, Set(ids).count)
    }
    
    func testEveryBundledNavigationLinkIsSupported() {
        let supported: Set<String> = Set(FAQDestination.allCases.map({ $0.rawValue }))
        
        for article in bundledArticles {
            for block in article.content {
                guard case .navigationLink(_, let destination) = block else { continue }
                XCTAssertTrue(supported.contains(destination.rawValue), "\(article.id) links to an unsupported destination")
            }
        }
    }
    
    func testEveryBundledSymbolExists() {
        for article in bundledArticles {
            guard let symbol: String = article.symbol else { continue }
            XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), "\(article.id) uses a missing symbol: \(symbol)")
        }
    }
    
    func testEveryBundledArticleHasContentAndADate() {
        for article in bundledArticles {
            XCTAssertFalse(article.title.isEmpty)
            XCTAssertFalse(article.content.isEmpty, "\(article.id) has no content")
            XCTAssertNotNil(article.lastUpdatedFormatted, "\(article.id) has an invalid date")
        }
    }
    
    func testUnknownDestinationFailsToDecode() {
        let json: String = #"{"schemaVersion":1,"sections":[{"id":"s","title":"S","articles":[{"id":"a","title":"A","lastUpdated":"2026-11-07","content":[{"type":"navigationLink","text":"Go","destination":"nowhere"}]}]}]}"#
        let sections: [FAQSection] = parser.sections(data: Data(json.utf8))
        XCTAssertTrue(sections.isEmpty)
    }
    
    func testEveryBlockTypeDecodes() {
        let json: String = #"{"schemaVersion":1,"sections":[{"id":"s","title":"S","articles":[{"id":"a","title":"A","lastUpdated":"2026-11-07","symbol":"star","content":[{"type":"paragraph","text":"P"},{"type":"bold","text":"B"},{"type":"numberedList","items":["1","2"]},{"type":"bulletList","items":["x"]},{"type":"navigationLink","text":"Go","destination":"contact"},{"type":"image","name":"pic"}]}]}]}"#
        let articles: [FAQArticle] = parser.sections(data: Data(json.utf8)).flatMap({ $0.articles })
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles.first?.content.count, 6)
        XCTAssertEqual(articles.first?.content.last, FAQContentBlock.image(name: "pic"))
    }
    
    func testMalformedJSONGivesNoSections() {
        XCTAssertTrue(parser.sections(data: Data("not json".utf8)).isEmpty)
    }
    
    func testLastUpdatedIsFormattedFromAGregorianDate() {
        let article: FAQArticle = FAQArticle(id: "a", title: "A", lastUpdated: "2026-11-07", symbol: nil, content: [])
        XCTAssertNotNil(article.lastUpdatedFormatted)
        XCTAssertTrue(article.lastUpdatedFormatted?.contains("2026") == true)
        XCTAssertNil(FAQArticle(id: "a", title: "A", lastUpdated: "soon", symbol: nil, content: []).lastUpdatedFormatted)
    }
    
    func testFeedbackStartsInitial() {
        let view: FAQFeedbackView = FAQFeedbackView()
        XCTAssertEqual(view.state, FAQFeedbackView.State.initial)
    }
    
    func testFAQPaneIsListedBetweenPrivacyAndAbout() {
        let panes: [SettingsPane] = SettingsPane.allCases
        XCTAssertEqual(panes.firstIndex(of: .faq), panes.firstIndex(of: .privacy)! + 1)
        XCTAssertEqual(panes.firstIndex(of: .about), panes.firstIndex(of: .faq)! + 1)
    }
}
