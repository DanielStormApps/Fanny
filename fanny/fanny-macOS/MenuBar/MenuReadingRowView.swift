//
//  MenuReadingRowView.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/24/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout
import SFSafeSymbols

/// A read only menu row drawn as a view, since macOS dims every disabled item's text and ignores its colors, so the values can stay full contrast.
final class MenuReadingRowView: NSView {
    
    private let imageView: NSImageView = NSImageView()
    private let titleLabel: NSTextField = NSTextField(labelWithString: "")
    private let valueLabel: NSTextField = NSTextField(labelWithString: "")
    /// Keeps the title clear of the value, and is swapped for a plain trailing edge on rows without a value.
    private var valueSpacingConstraint: NSLayoutConstraint?
    private var titleTrailingConstraint: NSLayoutConstraint?
    private var imageCenterConstraint: NSLayoutConstraint?
    
    /// The symbol sits in the menu's checkmark column, so the title lines up with the text of the menu's own items.
    private static let leadingInset: CGFloat = 12.0
    private static let imageColumnWidth: CGFloat = 18.0
    private static let trailingInset: CGFloat = 16.0
    static let valueSpacing: CGFloat = 24.0
    private static let rowHeight: CGFloat = 22.0
    private static let imageSize: CGFloat = 14.0
    
    private static let symbolConfiguration: NSImage.SymbolConfiguration = NSImage.SymbolConfiguration(pointSize: NSFont.menuFont(ofSize: 0.0).pointSize, weight: .regular, scale: .small)
    
    static var font: NSFont {
        return NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuFont(ofSize: 0.0).pointSize, weight: .regular)
    }
    
    // MARK: - Init
    /// - Parameter contentWidth: The widest title, spacing, and value of all rows, so every value lines up at the right edge.
    init(contentWidth: CGFloat) {
        let width: CGFloat = MenuReadingRowView.leadingInset + MenuReadingRowView.imageColumnWidth + contentWidth + MenuReadingRowView.trailingInset
        super.init(frame: NSRect(x: 0.0, y: 0.0, width: width, height: MenuReadingRowView.rowHeight))
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setup() {
        // The menu stretches the row to its width, so the value stays at the right edge.
        autoresizingMask = [.width]
        
        imageView.contentTintColor = NSColor.secondaryLabelColor
        addSubview(imageView)
        
        titleLabel.font = MenuReadingRowView.font
        titleLabel.textColor = NSColor.secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(titleLabel)
        titleLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: MenuReadingRowView.leadingInset + MenuReadingRowView.imageColumnWidth)
        titleLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        imageView.autoConstrainAttribute(.vertical, to: .leading, of: self, withOffset: MenuReadingRowView.leadingInset + MenuReadingRowView.imageSize / 2.0)
        imageCenterConstraint = imageView.autoConstrainAttribute(.horizontal, to: .lastBaseline, of: titleLabel)
        
        valueLabel.font = MenuReadingRowView.font
        valueLabel.textColor = NSColor.labelColor
        valueLabel.alignment = .right
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(valueLabel)
        valueLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: MenuReadingRowView.trailingInset)
        valueLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        valueSpacingConstraint = valueLabel.autoPinEdge(.leading, to: .trailing, of: titleLabel, withOffset: MenuReadingRowView.valueSpacing, relation: .greaterThanOrEqual)
        titleTrailingConstraint = titleLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: MenuReadingRowView.trailingInset, relation: .greaterThanOrEqual)
        
        // One VoiceOver stop per row, reading the title and value together.
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        imageView.setAccessibilityElement(false)
        titleLabel.setAccessibilityElement(false)
        valueLabel.setAccessibilityElement(false)
    }
    
    // MARK: - Configure
    func configure(row: MenuReadingRows.Row) {
        let image: NSImage? = row.symbol.flatMap({ NSImage(systemSymbol: $0, accessibilityDescription: nil).withSymbolConfiguration(MenuReadingRowView.symbolConfiguration) })
        imageView.image = image
        
        // Centers the symbol's ink on the title's capitals, since the symbol's canvas has uneven padding.
        if let image: NSImage = image {
            imageCenterConstraint?.constant = -MenuReadingRowView.font.capHeight / 2.0 + image.alignmentRect.midY - image.size.height / 2.0
        }
        titleLabel.stringValue = row.title
        valueLabel.stringValue = row.value ?? ""
        valueLabel.isHidden = row.value == nil
        valueSpacingConstraint?.isActive = row.value != nil
        titleTrailingConstraint?.isActive = row.value == nil
        setAccessibilityLabel(row.accessibilityText)
    }
}
