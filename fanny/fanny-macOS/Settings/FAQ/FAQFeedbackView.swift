//
//  FAQFeedbackView.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout
import SFSafeSymbols

// MARK: - FAQFeedbackViewDelegate
/// Listener told about the reader's feedback on an article.
protocol FAQFeedbackViewDelegate: AnyObject {
    func feedbackView(_ feedbackView: FAQFeedbackView, didSelectFeedback feedback: FAQFeedbackView.FeedbackType)
    func feedbackViewDidTapContact(_ feedbackView: FAQFeedbackView)
}

// MARK: - FAQFeedbackView
/// Shows "Was this article helpful?" with thumbs up and thumbs down buttons, then a Contact Us button after a thumbs down.
final class FAQFeedbackView: NSView {
    
    enum FeedbackType {
        case helpful
        case notHelpful
    }
    
    enum State {
        case initial
        case helpful
        case notHelpful
    }
    
    weak var delegate: FAQFeedbackViewDelegate?
    
    private(set) var state: State = State.initial
    
    private let titleLabel: NSTextField = NSTextField(labelWithString: String(localized: "Was this article helpful?", comment: "FAQ feedback: prompt"))
    private let thumbsUpButton: NSButton = NSButton(title: "", target: nil, action: nil)
    private let thumbsDownButton: NSButton = NSButton(title: "", target: nil, action: nil)
    private let contactButton: NSButton = NSButton(title: String(localized: "Contact Us", comment: "FAQ feedback: contact us button"), target: nil, action: nil)
    
    private static let verticalSpacing: CGFloat = 8.0
    private static let buttonSpacing: CGFloat = 24.0
    private static let buttonSize: CGFloat = 32.0
    private static let contactButtonTopSpacing: CGFloat = 12.0
    
    // MARK: - Init
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setup() {
        setupTitleLabel()
        setupButtons()
        setupContactButton()
        setupAccessibility()
        updateAppearance()
    }
    
    private func setupTitleLabel() {
        titleLabel.font = NSFont.preferredFont(forTextStyle: .callout)
        titleLabel.textColor = NSColor.secondaryLabelColor
        titleLabel.alignment = .center
        addSubview(titleLabel)
        titleLabel.autoPinEdge(toSuperviewEdge: .top)
        titleLabel.autoPinEdge(toSuperviewEdge: .leading)
        titleLabel.autoPinEdge(toSuperviewEdge: .trailing)
    }
    
    private func setupButtons() {
        configure(thumbsUpButton, symbol: SFSymbol.handThumbsup, action: #selector(thumbsUpClicked))
        configure(thumbsDownButton, symbol: SFSymbol.handThumbsdown, action: #selector(thumbsDownClicked))
        
        let buttonsStackView: NSStackView = NSStackView(views: [thumbsUpButton, thumbsDownButton])
        buttonsStackView.orientation = .horizontal
        buttonsStackView.alignment = .centerY
        buttonsStackView.spacing = FAQFeedbackView.buttonSpacing
        addSubview(buttonsStackView)
        buttonsStackView.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: FAQFeedbackView.verticalSpacing)
        buttonsStackView.autoAlignAxis(toSuperviewAxis: .vertical)
        
        thumbsUpButton.autoSetDimensions(to: CGSize(width: FAQFeedbackView.buttonSize, height: FAQFeedbackView.buttonSize))
        thumbsDownButton.autoSetDimensions(to: CGSize(width: FAQFeedbackView.buttonSize, height: FAQFeedbackView.buttonSize))
    }
    
    private func setupContactButton() {
        contactButton.bezelStyle = .rounded
        contactButton.target = self
        contactButton.action = #selector(contactClicked)
        contactButton.isHidden = true
        addSubview(contactButton)
        contactButton.autoPinEdge(.top, to: .bottom, of: thumbsUpButton, withOffset: FAQFeedbackView.contactButtonTopSpacing)
        contactButton.autoAlignAxis(toSuperviewAxis: .vertical)
        contactButton.autoPinEdge(toSuperviewEdge: .bottom)
    }
    
    private func configure(_ button: NSButton, symbol: SFSymbol, action: Selector) {
        button.image = NSImage(systemSymbol: symbol, accessibilityDescription: nil)
        button.imageScaling = .scaleProportionallyDown
        button.isBordered = false
        button.target = self
        button.action = action
    }
    
    // MARK: - State
    private func setState(_ newState: State) {
        guard state == .initial else { return }
        state = newState
        updateAppearance()
        announceFeedbackReceived()
    }
    
    private func updateAppearance() {
        switch state {
        case .initial:
            thumbsUpButton.contentTintColor = NSColor.labelColor
            thumbsDownButton.contentTintColor = NSColor.labelColor
            contactButton.isHidden = true
        
        case .helpful:
            thumbsUpButton.contentTintColor = NSColor.systemGreen
            thumbsDownButton.contentTintColor = NSColor.tertiaryLabelColor
            contactButton.isHidden = true
        
        case .notHelpful:
            thumbsUpButton.contentTintColor = NSColor.tertiaryLabelColor
            thumbsDownButton.contentTintColor = NSColor.systemRed
            contactButton.isHidden = false
        }
        
        updateAccessibilityState()
    }
    
    // MARK: - Actions
    @objc private func thumbsUpClicked() {
        guard state == .initial else { return }
        setState(.helpful)
        delegate?.feedbackView(self, didSelectFeedback: .helpful)
    }
    
    @objc private func thumbsDownClicked() {
        guard state == .initial else { return }
        setState(.notHelpful)
        delegate?.feedbackView(self, didSelectFeedback: .notHelpful)
    }
    
    @objc private func contactClicked() {
        delegate?.feedbackViewDidTapContact(self)
    }
    
    // MARK: - Accessibility
    private func updateAccessibilityState() {
        let selectedValue: String = String(localized: "Selected", comment: "FAQ feedback: accessibility value of the thumbs button the reader chose.")
        thumbsUpButton.setAccessibilitySelected(state == .helpful)
        thumbsUpButton.setAccessibilityValue(state == .helpful ? selectedValue : nil)
        thumbsDownButton.setAccessibilitySelected(state == .notHelpful)
        thumbsDownButton.setAccessibilityValue(state == .notHelpful ? selectedValue : nil)
    }
    
    private func announceFeedbackReceived() {
        let announcement: String
        
        if state == .notHelpful {
            announcement = String(localized: "Thanks for your feedback. A Contact Us button is now available.", comment: "FAQ feedback: VoiceOver announcement after a thumbs down, which reveals the Contact Us button.")
        }
        else {
            announcement = String(localized: "Thanks for your feedback.", comment: "FAQ feedback: VoiceOver announcement after a thumbs up.")
        }
        
        NSAccessibility.post(element: self, notification: .announcementRequested, userInfo: [.announcement: announcement,
                                                                                            .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
    
    private func setupAccessibility() {
        thumbsUpButton.setAccessibilityLabel(String(localized: "Yes, helpful", comment: "FAQ feedback: thumbs up accessibility label"))
        thumbsDownButton.setAccessibilityLabel(String(localized: "No, not helpful", comment: "FAQ feedback: thumbs down accessibility label"))
    }
}
