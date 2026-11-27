//
//  FAQArticleContentView.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout

// MARK: - FAQArticleContentViewDelegate
/// Listener told when a navigation link in an article is clicked.
protocol FAQArticleContentViewDelegate: AnyObject {
    func contentView(_ contentView: FAQArticleContentView, didTapNavigationLink destination: FAQDestination)
}

// MARK: - FAQArticleContentView
/// Renders FAQ article content blocks as a vertical stack.
final class FAQArticleContentView: NSView {
    
    weak var delegate: FAQArticleContentViewDelegate?
    
    private let stackView: NSStackView = NSStackView()
    
    private static let blockSpacing: CGFloat = 12.0
    private static let listItemSpacing: CGFloat = 6.0
    private static let listIndent: CGFloat = 16.0
    private static let prefixToTextSpacing: CGFloat = 4.0
    private static let bodyFont: NSFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    private static let boldFont: NSFont = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
    private static let rightToLeftMark: String = "\u{200F}"
    
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
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = FAQArticleContentView.blockSpacing
        addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
    }
    
    // MARK: - Configure
    func configure(with contentBlocks: [FAQContentBlock]) {
        for subview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        for block in contentBlocks {
            guard let blockView: NSView = makeView(for: block) else { continue }
            stackView.addArrangedSubview(blockView)
            
            if blockView is FAQNavigationLinkButton {
                continue
            }
            
            blockView.autoPinEdge(toSuperviewEdge: .trailing)
        }
    }
    
    // MARK: - Block Rendering
    private func makeView(for block: FAQContentBlock) -> NSView? {
        let view: NSView?
        
        switch block {
        case .paragraph(let text):
            view = makeLabel(text: text, font: FAQArticleContentView.bodyFont)
        case .bold(let text):
            let label: NSTextField = makeLabel(text: text, font: FAQArticleContentView.boldFont)
            // Bold blocks work as sub-headings. AppKit has no heading constant; AXHeading is the role VoiceOver uses for its heading navigation.
            label.setAccessibilityRole(NSAccessibility.Role(rawValue: "AXHeading"))
            view = label
        case .numberedList(let items):
            view = makeNumberedListView(items: items)
        case .bulletList(let items):
            view = makeBulletListView(items: items)
        case .navigationLink(let text, let destination):
            view = makeNavigationLinkButton(text: text, destination: destination)
        case .image(let name):
            view = makeImageView(name: name)
        }
        
        return view
    }
    
    private func makeLabel(text: String, font: NSFont) -> NSTextField {
        let label: NSTextField = NSTextField(wrappingLabelWithString: text)
        label.isSelectable = false
        label.font = font
        label.textColor = NSColor.labelColor
        return label
    }
    
    private func makeNumberedListView(items: [String]) -> NSView {
        // The right-to-left mark sets the marker's direction, so the period sits on the reading-end side.
        let directionMark: String = NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? FAQArticleContentView.rightToLeftMark : String()
        var prefixes: [String] = []
        var accessibilityLabels: [String] = []
        
        for (index, item) in items.enumerated() {
            let number: String = "\((index + 1).formatted())."
            prefixes.append(directionMark + number)
            accessibilityLabels.append(number + " " + item)
        }
        
        return makeListView(prefixes: prefixes, accessibilityLabels: accessibilityLabels, items: items)
    }
    
    private func makeBulletListView(items: [String]) -> NSView {
        let prefixes: [String] = Array(repeating: "•", count: items.count)
        return makeListView(prefixes: prefixes, accessibilityLabels: items, items: items)
    }
    
    private func makeListView(prefixes: [String], accessibilityLabels: [String], items: [String]) -> NSView {
        let listStackView: NSStackView = NSStackView()
        listStackView.orientation = .vertical
        listStackView.alignment = .leading
        listStackView.spacing = FAQArticleContentView.listItemSpacing
        
        for index in 0..<items.count {
            let itemView: NSView = makeListItemView(prefix: prefixes[index], accessibilityLabel: accessibilityLabels[index], text: items[index])
            listStackView.addArrangedSubview(itemView)
            itemView.autoPinEdge(toSuperviewEdge: .trailing)
        }
        
        return listStackView
    }
    
    private func makeListItemView(prefix: String, accessibilityLabel: String, text: String) -> NSView {
        let containerView: NSView = NSView()
        
        let prefixLabel: NSTextField = NSTextField(labelWithString: prefix)
        prefixLabel.font = FAQArticleContentView.bodyFont
        prefixLabel.textColor = NSColor.labelColor
        prefixLabel.setContentHuggingPriority(.required, for: .horizontal)
        prefixLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        // VoiceOver reads the marker as part of the item's text, so it is one stop instead of two.
        prefixLabel.hideFromAccessibility()
        
        let textLabel: NSTextField = makeLabel(text: text, font: FAQArticleContentView.bodyFont)
        textLabel.setAccessibilityLabel(accessibilityLabel)
        
        containerView.addSubview(prefixLabel)
        containerView.addSubview(textLabel)
        
        prefixLabel.autoPinEdge(toSuperviewEdge: .top)
        prefixLabel.autoPinEdge(toSuperviewEdge: .leading)
        prefixLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        prefixLabel.autoSetDimension(.width, toSize: FAQArticleContentView.listIndent, relation: .greaterThanOrEqual)
        
        textLabel.autoPinEdge(.leading, to: .trailing, of: prefixLabel, withOffset: FAQArticleContentView.prefixToTextSpacing)
        textLabel.autoPinEdge(toSuperviewEdge: .top)
        textLabel.autoPinEdge(toSuperviewEdge: .trailing)
        textLabel.autoPinEdge(toSuperviewEdge: .bottom)
        
        return containerView
    }
    
    private func makeNavigationLinkButton(text: String, destination: FAQDestination) -> NSView {
        let button: FAQNavigationLinkButton = FAQNavigationLinkButton()
        button.destination = destination
        button.isBordered = false
        button.alignment = .left
        button.target = self
        button.action = #selector(navigationLinkClicked(_:))
        button.attributedTitle = NSAttributedString(string: text, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue,
                                                                               .font: FAQArticleContentView.bodyFont,
                                                                               .foregroundColor: NSColor.linkColor])
        button.setAccessibilityLabel(text)
        button.setAccessibilityRole(.link)
        button.setAccessibilityHelp(accessibilityHelp(for: destination))
        return button
    }
    
    private func accessibilityHelp(for destination: FAQDestination) -> String {
        let help: String
        
        switch destination {
        case .settingsGeneral, .settingsMenuBar, .settingsFloatingWindow, .settingsSensors, .settingsAppearance, .settingsPrivacy:
            help = String(localized: "Opens a Settings pane", comment: "Accessibility hint: a link that switches to another pane of the Fanny settings window.")
        case .contact:
            help = String(localized: "Opens Mail", comment: "FAQ accessibility hint: a link that opens an email to support in the Mail app.")
        case .positive:
            help = String(localized: "Opens the App Store", comment: "FAQ accessibility hint: a link that opens the App Store page of Positive, the developer's other app.")
        }
        
        return help
    }
    
    private func makeImageView(name: String) -> NSView? {
        guard let image: NSImage = NSImage(named: name) else {
            Log.warn("📖 makeImageView -> image not found -> name: \(name)")
            return nil
        }
        
        let imageView: NSImageView = NSImageView(image: image)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.hideFromAccessibility()
        
        let aspectRatio: CGFloat = image.size.height > 0.0 ? image.size.width / image.size.height : 1.0
        imageView.autoMatch(.width, to: .height, of: imageView, withMultiplier: aspectRatio)
        
        return imageView
    }
    
    // MARK: - Actions
    @objc private func navigationLinkClicked(_ sender: FAQNavigationLinkButton) {
        guard let destination: FAQDestination = sender.destination else { return }
        delegate?.contentView(self, didTapNavigationLink: destination)
    }
}

// MARK: - FAQNavigationLinkButton
/// A link-styled button that remembers where it leads.
private final class FAQNavigationLinkButton: NSButton {
    
    var destination: FAQDestination?
    
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: NSCursor.pointingHand)
    }
}
