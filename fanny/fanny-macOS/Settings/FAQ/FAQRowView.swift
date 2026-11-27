//
//  FAQRowView.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout
import SFSafeSymbols

/// A clickable settings row showing an article's symbol, its title, and a trailing chevron.
final class FAQRowView: NSView {
    
    private let article: FAQArticle
    private let onSelect: (FAQArticle) -> Void
    
    private var isHovered: Bool = false
    private var isPressed: Bool = false
    private var trackingArea: NSTrackingArea?
    
    private static let minimumHeight: CGFloat = 44.0
    private static let horizontalInset: CGFloat = 16.0
    private static let verticalInset: CGFloat = 10.0
    private static let iconSize: CGFloat = 20.0
    private static let iconToTitleSpacing: CGFloat = 12.0
    private static let titleToChevronSpacing: CGFloat = 12.0
    private static let spaceKeyCode: UInt16 = 49
    private static let returnKeyCode: UInt16 = 36
    private static let enterKeyCode: UInt16 = 76
    private static let hoverAlpha: CGFloat = 0.06
    private static let pressedAlpha: CGFloat = 0.12
    
    override var wantsUpdateLayer: Bool {
        return true
    }
    
    // MARK: - Init
    init(article: FAQArticle, onSelect: @escaping (FAQArticle) -> Void) {
        self.article = article
        self.onSelect = onSelect
        super.init(frame: CGRect.zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setup() {
        wantsLayer = true
        
        let iconImageView: NSImageView = NSImageView(image: symbolImage())
        iconImageView.imageScaling = .scaleProportionallyDown
        iconImageView.contentTintColor = NSColor.labelColor
        iconImageView.hideFromAccessibility()
        
        let titleLabel: NSTextField = NSTextField(wrappingLabelWithString: article.title)
        titleLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.isSelectable = false
        titleLabel.hideFromAccessibility()
        
        let chevronSymbol: SFSymbol = NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? SFSymbol.chevronLeft : SFSymbol.chevronRight
        let chevronImageView: NSImageView = NSImageView(image: NSImage(systemSymbol: chevronSymbol, accessibilityDescription: nil))
        chevronImageView.imageScaling = .scaleProportionallyDown
        chevronImageView.contentTintColor = NSColor.tertiaryLabelColor
        chevronImageView.hideFromAccessibility()
        chevronImageView.setContentHuggingPriority(.required, for: .horizontal)
        chevronImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(chevronImageView)
        
        autoSetDimension(.height, toSize: FAQRowView.minimumHeight, relation: .greaterThanOrEqual)
        
        iconImageView.autoPinEdge(toSuperviewEdge: .leading, withInset: FAQRowView.horizontalInset)
        iconImageView.autoAlignAxis(toSuperviewAxis: .horizontal)
        iconImageView.autoSetDimensions(to: CGSize(width: FAQRowView.iconSize, height: FAQRowView.iconSize))
        
        titleLabel.autoPinEdge(.leading, to: .trailing, of: iconImageView, withOffset: FAQRowView.iconToTitleSpacing)
        titleLabel.autoPinEdge(toSuperviewEdge: .top, withInset: FAQRowView.verticalInset, relation: .greaterThanOrEqual)
        titleLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: FAQRowView.verticalInset, relation: .greaterThanOrEqual)
        titleLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        chevronImageView.autoPinEdge(toSuperviewEdge: .trailing, withInset: FAQRowView.horizontalInset)
        chevronImageView.autoAlignAxis(toSuperviewAxis: .horizontal)
        chevronImageView.autoPinEdge(.leading, to: .trailing, of: titleLabel, withOffset: FAQRowView.titleToChevronSpacing)
        
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(article.title)
        setAccessibilityHelp(String(localized: "Opens the article", comment: "FAQ row accessibility hint: pressing the row opens the article."))
        focusRingType = .default
    }
    
    private func symbolImage() -> NSImage {
        let image: NSImage
        let fallbackImage: NSImage = NSImage(systemSymbol: SFSymbol.questionmarkCircle, accessibilityDescription: nil)
        
        if let symbolName: String = article.symbol {
            if let articleImage: NSImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                image = articleImage
            }
            else {
                Log.warn("📖 symbolImage -> symbol not found -> name: \(symbolName)")
                image = fallbackImage
            }
        }
        else {
            image = fallbackImage
        }
        
        return image
    }
    
    // MARK: - Tracking
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea: NSTrackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let area: NSTrackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }
    
    /// A row removed from the window never gets mouseExited, so it would keep its highlight after Back.
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        guard newWindow == nil else { return }
        isHovered = false
        isPressed = false
        needsDisplay = true
    }
    
    // MARK: - Keyboard
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override var focusRingMaskBounds: NSRect {
        return bounds
    }
    
    override func drawFocusRingMask() {
        NSBezierPath(rect: bounds).fill()
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case FAQRowView.spaceKeyCode, FAQRowView.returnKeyCode, FAQRowView.enterKeyCode:
            onSelect(article)
        default:
            super.keyDown(with: event)
        }
    }
    
    // MARK: - Mouse
    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        let wasPressed: Bool = isPressed
        isPressed = false
        needsDisplay = true
        
        let location: CGPoint = convert(event.locationInWindow, from: nil)
        guard wasPressed, bounds.contains(location) else { return }
        onSelect(article)
    }
    
    // MARK: - Accessibility
    override func accessibilityPerformPress() -> Bool {
        onSelect(article)
        return true
    }
    
    // MARK: - Appearance
    override func updateLayer() {
        super.updateLayer()
        
        let alpha: CGFloat
        
        if isPressed {
            alpha = FAQRowView.pressedAlpha
        }
        else if isHovered {
            alpha = FAQRowView.hoverAlpha
        }
        else {
            alpha = 0.0
        }
        
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(alpha).cgColor
        }
    }
}
