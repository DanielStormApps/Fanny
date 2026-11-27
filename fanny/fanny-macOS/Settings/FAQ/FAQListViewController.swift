//
//  FAQListViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout

// MARK: - FAQListViewControllerDelegate
/// Listener told when an article is picked from the list.
protocol FAQListViewControllerDelegate: AnyObject {
    func faqListViewController(_ viewController: FAQListViewController, didSelect article: FAQArticle)
}

// MARK: - FAQListViewController
/// The FAQ list: one card per section, one row per article.
final class FAQListViewController: ViewController {
    
    weak var delegate: FAQListViewControllerDelegate?
    
    private let settingsScrollView: SettingsScrollView = SettingsScrollView()
    private let articleParser: FAQArticleParser = FAQArticleParser()
    
    private var rowViews: [String: FAQRowView] = [:]
    
    /// The scroll position, so Back can return to where the list was left.
    var scrollOffset: CGPoint {
        get {
            return settingsScrollView.contentView.bounds.origin
        }
        set {
            settingsScrollView.contentView.scroll(to: newValue)
            settingsScrollView.reflectScrolledClipView(settingsScrollView.contentView)
        }
    }
    
    // MARK: - View Cycle
    override func loadView() {
        view = settingsScrollView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analyticsIsEnabled = false
        setupSections()
    }
    
    // MARK: - Accessibility
    /// Moves the VoiceOver cursor back to the row that opened an article.
    func focusAccessibilityRow(for article: FAQArticle) {
        guard let row: FAQRowView = rowViews[article.id] else { return }
        NSAccessibility.post(element: row, notification: .focusedUIElementChanged)
    }
    
    // MARK: - Setup
    private func setupSections() {
        let sections: [FAQSection] = articleParser.sections(resource: "faq-articles")
        
        for section in sections {
            let group: SettingsGroupView = SettingsGroupView()
            
            for article in section.articles {
                let row: FAQRowView = FAQRowView(article: article) { [weak self] selectedArticle in
                    guard let strongSelf: FAQListViewController = self else { return }
                    strongSelf.delegate?.faqListViewController(strongSelf, didSelect: selectedArticle)
                }
                rowViews[article.id] = row
                group.addRow(row)
            }
            
            settingsScrollView.addGroup(group, header: section.title)
        }
    }
}
