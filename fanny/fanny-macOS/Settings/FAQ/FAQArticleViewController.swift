//
//  FAQArticleViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout
import SFSafeSymbols

// MARK: - FAQArticleViewControllerDelegate
/// Listener told about the reader's actions inside an article.
protocol FAQArticleViewControllerDelegate: AnyObject {
    func faqArticleViewControllerDidTapBack(_ viewController: FAQArticleViewController)
    func faqArticleViewController(_ viewController: FAQArticleViewController, didTapNavigationLink destination: FAQDestination)
    func faqArticleViewController(_ viewController: FAQArticleViewController, didTapContactFor article: FAQArticle)
}

// MARK: - FAQArticleViewController
/// Shows one FAQ article with a back button, its content blocks, and the feedback block.
final class FAQArticleViewController: ViewController {
    
    weak var delegate: FAQArticleViewControllerDelegate?
    
    private let article: FAQArticle
    private let settingsScrollView: SettingsScrollView = SettingsScrollView()
    private let backButton: NSButton = NSButton(title: "", target: nil, action: nil)
    private let titleLabel: NSTextField = NSTextField(wrappingLabelWithString: "")
    private let lastUpdatedLabel: NSTextField = NSTextField(labelWithString: "")
    private let articleContentView: FAQArticleContentView = FAQArticleContentView()
    private let feedbackView: FAQFeedbackView = FAQFeedbackView()
    
    private var hasTrackedFeedback: Bool = false
    
    private static let contentInset: CGFloat = 4.0
    private static let backButtonSize: CGFloat = 28.0
    private static let backButtonToTitleSpacing: CGFloat = 16.0
    private static let titleToLastUpdatedSpacing: CGFloat = 6.0
    private static let lastUpdatedToContentSpacing: CGFloat = 20.0
    private static let contentToFeedbackSpacing: CGFloat = 32.0
    
    // MARK: - Init
    init(article: FAQArticle) {
        self.article = article
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Cycle
    override func loadView() {
        view = settingsScrollView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analytics(title: "faq_" + article.title)
        analyticsIsEnabled = false
        setupView()
        configureContent()
    }
    
    // MARK: - Setup
    private func setupView() {
        let containerView: NSView = NSView()
        setupBackButton(in: containerView)
        setupTitleLabel(in: containerView)
        setupLastUpdatedLabel(in: containerView)
        setupArticleContentView(in: containerView)
        setupFeedbackView(in: containerView)
        settingsScrollView.addGroup(containerView)
    }
    
    private func setupBackButton(in containerView: NSView) {
        let backSymbol: SFSymbol = NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? SFSymbol.chevronRight : SFSymbol.chevronLeft
        backButton.image = NSImage(systemSymbol: backSymbol, accessibilityDescription: nil)
        backButton.imagePosition = .imageOnly
        backButton.bezelStyle = .circular
        backButton.target = self
        backButton.action = #selector(backClicked)
        // ⌘[ is the standard Back shortcut, as in Safari, Finder, and System Settings.
        backButton.keyEquivalent = "["
        backButton.keyEquivalentModifierMask = .command
        backButton.setAccessibilityLabel(String(localized: "Back", comment: "FAQ article: accessibility label of the button that returns to the list."))
        
        containerView.addSubview(backButton)
        backButton.autoPinEdge(toSuperviewEdge: .top)
        backButton.autoPinEdge(toSuperviewEdge: .leading)
        backButton.autoSetDimensions(to: CGSize(width: FAQArticleViewController.backButtonSize, height: FAQArticleViewController.backButtonSize))
    }
    
    private func setupTitleLabel(in containerView: NSView) {
        titleLabel.isSelectable = false
        titleLabel.font = NSFont.systemFont(ofSize: NSFont.preferredFont(forTextStyle: .title1).pointSize, weight: .bold)
        titleLabel.textColor = NSColor.labelColor
        // AppKit has no heading constant; AXHeading is the role VoiceOver uses for its heading navigation.
        titleLabel.setAccessibilityRole(NSAccessibility.Role(rawValue: "AXHeading"))
        
        containerView.addSubview(titleLabel)
        titleLabel.autoPinEdge(.top, to: .bottom, of: backButton, withOffset: FAQArticleViewController.backButtonToTitleSpacing)
        titleLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: FAQArticleViewController.contentInset)
        titleLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: FAQArticleViewController.contentInset)
    }
    
    private func setupLastUpdatedLabel(in containerView: NSView) {
        lastUpdatedLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        lastUpdatedLabel.textColor = NSColor.tertiaryLabelColor
        
        containerView.addSubview(lastUpdatedLabel)
        lastUpdatedLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: FAQArticleViewController.titleToLastUpdatedSpacing)
        lastUpdatedLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: FAQArticleViewController.contentInset)
        lastUpdatedLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: FAQArticleViewController.contentInset)
    }
    
    private func setupArticleContentView(in containerView: NSView) {
        articleContentView.delegate = self
        
        containerView.addSubview(articleContentView)
        articleContentView.autoPinEdge(.top, to: .bottom, of: lastUpdatedLabel, withOffset: FAQArticleViewController.lastUpdatedToContentSpacing)
        articleContentView.autoPinEdge(toSuperviewEdge: .leading, withInset: FAQArticleViewController.contentInset)
        articleContentView.autoPinEdge(toSuperviewEdge: .trailing, withInset: FAQArticleViewController.contentInset)
    }
    
    private func setupFeedbackView(in containerView: NSView) {
        feedbackView.delegate = self
        
        containerView.addSubview(feedbackView)
        feedbackView.autoPinEdge(.top, to: .bottom, of: articleContentView, withOffset: FAQArticleViewController.contentToFeedbackSpacing)
        feedbackView.autoPinEdge(toSuperviewEdge: .leading, withInset: FAQArticleViewController.contentInset)
        feedbackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: FAQArticleViewController.contentInset)
        feedbackView.autoPinEdge(toSuperviewEdge: .bottom)
    }
    
    // MARK: - Configure
    private func configureContent() {
        titleLabel.stringValue = article.title
        titleLabel.setAccessibilityLabel(article.title)
        articleContentView.configure(with: article.content)
        
        if let formattedDate: String = article.lastUpdatedFormatted {
            lastUpdatedLabel.stringValue = String(localized: "Last updated \(formattedDate)", comment: "FAQ article: last updated date line. The argument is a date.")
            
            // VoiceOver reads a dotted numeric date as numbers, so it hears the date spelled out instead.
            if let date: Date = article.lastUpdatedDate {
                let spokenDate: String = date.formatted(date: .long, time: .omitted)
                lastUpdatedLabel.setAccessibilityLabel(String(localized: "Last updated \(spokenDate)", comment: "FAQ article: last updated date line. The argument is a date."))
            }
        }
        else {
            lastUpdatedLabel.isHidden = true
        }
    }
    
    // MARK: - Accessibility
    /// Moves the VoiceOver cursor to the article title, since the row that was pressed has left the window.
    func focusAccessibilityTitle() {
        NSAccessibility.post(element: titleLabel, notification: .focusedUIElementChanged)
    }
    
    // MARK: - Actions
    @objc private func backClicked() {
        delegate?.faqArticleViewControllerDidTapBack(self)
    }
    
    // MARK: - Analytics
    private func trackFeedbackEvent(feedbackType: FAQFeedbackEvent.FeedbackType) {
        guard hasTrackedFeedback == false else { return }
        hasTrackedFeedback = true
        
        var event: FAQFeedbackEvent = FAQFeedbackEvent()
        event.articleID = article.id
        event.feedbackType = feedbackType
        
        Analytics.shared.track(event: event)
    }
}

// MARK: - FAQArticleContentViewDelegate
extension FAQArticleViewController: FAQArticleContentViewDelegate {
    
    func contentView(_ contentView: FAQArticleContentView, didTapNavigationLink destination: FAQDestination) {
        delegate?.faqArticleViewController(self, didTapNavigationLink: destination)
    }
}

// MARK: - FAQFeedbackViewDelegate
extension FAQArticleViewController: FAQFeedbackViewDelegate {
    
    func feedbackView(_ feedbackView: FAQFeedbackView, didSelectFeedback feedback: FAQFeedbackView.FeedbackType) {
        let eventFeedbackType: FAQFeedbackEvent.FeedbackType
        
        switch feedback {
        case .helpful:
            eventFeedbackType = .helpful
        case .notHelpful:
            eventFeedbackType = .notHelpful
        }
        
        trackFeedbackEvent(feedbackType: eventFeedbackType)
    }
    
    func feedbackViewDidTapContact(_ feedbackView: FAQFeedbackView) {
        delegate?.faqArticleViewController(self, didTapContactFor: article)
    }
}
