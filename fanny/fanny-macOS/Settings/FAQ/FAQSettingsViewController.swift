//
//  FAQSettingsViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout

/// The FAQ pane: the article list, which swaps for an article and back without leaving the pane.
final class FAQSettingsViewController: ViewController {
    
    private let listViewController: FAQListViewController = FAQListViewController()
    
    private var articleViewController: FAQArticleViewController?
    private var openedArticle: FAQArticle?
    private var savedListScrollOffset: CGPoint = CGPoint.zero
    
    // MARK: - View Cycle
    override func loadView() {
        view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analytics(title: "faq")
        listViewController.delegate = self
        addChild(listViewController)
        embed(listViewController.view)
    }
    
    // MARK: - Setup
    private func embed(_ childView: NSView) {
        view.addSubview(childView)
        childView.autoPinEdgesToSuperviewEdges()
    }
    
    // MARK: - Navigation
    private func show(_ article: FAQArticle) {
        savedListScrollOffset = listViewController.scrollOffset
        listViewController.view.removeFromSuperview()
        
        let articleViewController: FAQArticleViewController = FAQArticleViewController(article: article)
        articleViewController.delegate = self
        addChild(articleViewController)
        embed(articleViewController.view)
        self.articleViewController = articleViewController
        openedArticle = article
        articleViewController.focusAccessibilityTitle()
        
        if let title: String = articleViewController.analyticsTitle {
            analytics(title: title)
            trackPageViewEvent()
        }
    }
    
    private func showList() {
        articleViewController?.view.removeFromSuperview()
        articleViewController?.removeFromParent()
        articleViewController = nil
        
        embed(listViewController.view)
        view.layoutSubtreeIfNeeded()
        listViewController.scrollOffset = savedListScrollOffset
        
        if let article: FAQArticle = openedArticle {
            listViewController.focusAccessibilityRow(for: article)
        }
        
        openedArticle = nil
        
        analytics(title: "faq")
        trackPageViewEvent()
    }
    
    private func navigate(to destination: FAQDestination) {
        switch destination {
        case .settingsGeneral:
            trackAction("faq_OpenGeneral")
            SettingsWindowController.shared.show(pane: .general)
        case .settingsMenuBar:
            trackAction("faq_OpenMenuBar")
            SettingsWindowController.shared.show(pane: .menuBar)
        case .settingsFloatingWindow:
            trackAction("faq_OpenFloatingWindow")
            SettingsWindowController.shared.show(pane: .floatingWindow)
        case .settingsSensors:
            trackAction("faq_OpenSensors")
            SettingsWindowController.shared.show(pane: .sensors)
        case .settingsAppearance:
            trackAction("faq_OpenAppearance")
            SettingsWindowController.shared.show(pane: .appearance)
        case .settingsPrivacy:
            trackAction("faq_OpenPrivacy")
            SettingsWindowController.shared.show(pane: .privacy)
        case .contact:
            trackAction("faq_Contact")
            SupportMail.compose(subject: SupportMail.defaultSubject)
        case .positive:
            trackAction("faq_DownloadPositive")
            PositiveApp.openAppStore()
        }
    }
    
    // MARK: - Analytics
    private func trackAction(_ title: String) {
        let event: PageViewEvent = PageViewEvent(title: title)
        Analytics.shared.track(event: event)
    }
}

// MARK: - FAQListViewControllerDelegate
extension FAQSettingsViewController: FAQListViewControllerDelegate {
    
    func faqListViewController(_ viewController: FAQListViewController, didSelect article: FAQArticle) {
        show(article)
    }
}

// MARK: - FAQArticleViewControllerDelegate
extension FAQSettingsViewController: FAQArticleViewControllerDelegate {
    
    func faqArticleViewControllerDidTapBack(_ viewController: FAQArticleViewController) {
        showList()
    }
    
    func faqArticleViewController(_ viewController: FAQArticleViewController, didTapNavigationLink destination: FAQDestination) {
        navigate(to: destination)
    }
    
    func faqArticleViewController(_ viewController: FAQArticleViewController, didTapContactFor article: FAQArticle) {
        trackAction("faq_Contact")
        SupportMail.compose(subject: String(localized: "Fanny - Contact - \(article.title)", comment: "FAQ: contact email subject. The argument is the article title (keep app name)."))
    }
}
