//
//  MenuBarController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import SFSafeSymbols

/// A controller that owns the app's menu bar item and its menu.
final class MenuBarController: NSObject {
    
    private var statusItem: NSStatusItem?
    private var menu: NSMenu = NSMenu()
    private var isMenuOpen: Bool = false
    /// Set when the menu opens with Option held, like the Wi-Fi menu's extra details, and kept until it closes.
    private var showsDeveloperMenuItem: Bool = false
    private var lastButtonContent: MenuBarButtonContent?
    private var lastReadingRows: MenuReadingRows?
    /// The reading rows' items, in the same order as `lastReadingRows`, so an open menu updates them in place.
    private var readingItems: [NSMenuItem] = []
    /// The rows' content width, so a value that outgrows it rebuilds the rows wider instead of truncating its title.
    private var readingContentWidth: CGFloat = 0.0
    
    private static let statusItemAutosaveName: String = "FannyStatusItem"
    
    // MARK: - Setup
    func setup() {
        let statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = MenuBarController.statusItemAutosaveName
        
        statusItem.button?.image = MenuBarController.iconImage
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.setAccessibilityLabel(String(localized: "Fanny", comment: "Accessibility label of the menu bar button. The app name (keep Fanny)."))
        
        menu.delegate = self
        statusItem.menu = menu
        self.statusItem = statusItem
        
        SensorMonitor.shared.delegate.add(self)
        FannySettingsManager.shared.delegate.add(self)
        UpdateChecker.shared.delegate.add(self)
        
        updateButton()
        rebuildMenu()
    }
    
    // MARK: - Button
    private func updateButton() {
        guard let button: NSStatusBarButton = statusItem?.button else { return }
        
        let content: MenuBarButtonContent = MenuBarButtonContent(snapshot: SensorMonitor.shared.snapshot, settings: FannySettingsManager.shared.settings)
        guard content != lastButtonContent else { return }
        
        if content.segments != lastButtonContent?.segments || content.showsIcon != lastButtonContent?.showsIcon {
            button.image = MenuBarController.buttonImage(for: content)
        }
        
        if content.toolTip != lastButtonContent?.toolTip {
            button.toolTip = content.toolTip
            // The value already speaks every reading, so VoiceOver should not read the visual tooltip as help.
            button.setAccessibilityHelp("")
        }
        
        // The label stays the app name so the item keeps a stable identity; the changing readings live in the value.
        if content.accessibilityValue != lastButtonContent?.accessibilityValue {
            button.setAccessibilityValue(content.accessibilityValue)
        }
        
        lastButtonContent = content
    }
    
    private static let iconImage: NSImage = {
        let image: NSImage = NSImage(systemSymbol: .fanFill, accessibilityDescription: nil)
        image.isTemplate = true
        return image
    }()
    
    /// A little taller than the tallest system menu bar icons, such as Bluetooth and Now Playing at about 14pt, so the value stays readable without towering over them.
    private static let maximumInkHeight: CGFloat = 16.5
    private static let baseLabelSpacing: CGFloat = 3.0
    /// Shrinks the value, the label under it, and the gap between them together, so they keep their proportions and fit `maximumInkHeight`.
    private static let textScale: CGFloat = {
        let valueCapHeight: CGFloat = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium).capHeight
        let labelCapHeight: CGFloat = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .mini), weight: .semibold).capHeight
        return min(maximumInkHeight / (valueCapHeight + baseLabelSpacing + labelCapHeight), 1.0)
    }()
    private static let buttonValueFont: NSFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize * textScale, weight: .medium)
    private static let buttonLabelFont: NSFont = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .mini) * textScale, weight: .semibold)
    private static let labelSpacing: CGFloat = baseLabelSpacing * textScale
    private static let segmentSpacing: CGFloat = 6.0
    private static let iconSpacing: CGFloat = 4.0
    private static let buttonImageHeight: CGFloat = 22.0
    
    /// One value and the label under it, placed so the label centers on the value's digits.
    private struct SegmentLayout {
        let value: CTLine
        let label: CTLine
        let valueX: CGFloat
        let labelX: CGFloat
        let width: CGFloat
    }
    
    /// Draws the icon and every value into one template image, so each label can sit under its value and the system still tints it for the menu bar.
    private static func buttonImage(for content: MenuBarButtonContent) -> NSImage {
        let icon: NSImage? = content.showsIcon ? iconImage : nil
        let layouts: [SegmentLayout] = content.segments.map({ segmentLayout(for: $0) })
        let iconWidth: CGFloat = icon?.size.width ?? 0.0
        let textWidth: CGFloat = layouts.map({ $0.width }).reduce(0.0, +) + segmentSpacing * CGFloat(max(layouts.count - 1, 0))
        let width: CGFloat = iconWidth + (icon != nil && layouts.isEmpty == false ? iconSpacing : 0.0) + textWidth
        let height: CGFloat = buttonImageHeight
        
        let image: NSImage = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            guard let context: CGContext = NSGraphicsContext.current?.cgContext else { return false }
            var inkCenterY: CGFloat = height / 2.0
            var x: CGFloat = 0.0
            
            if let icon: NSImage = icon {
                let iconRect: NSRect = NSRect(x: 0.0, y: ((height - icon.size.height) / 2.0).rounded(), width: icon.size.width, height: icon.size.height)
                icon.draw(in: iconRect)
                // Centers the text on the fan's ink, not on the symbol's padded canvas.
                inkCenterY = iconRect.minY + icon.alignmentRect.midY
                x = iconRect.maxX + (layouts.isEmpty ? 0.0 : iconSpacing)
            }
            
            let inkHeight: CGFloat = buttonValueFont.capHeight + labelSpacing + buttonLabelFont.capHeight
            let labelBaseline: CGFloat = inkCenterY - inkHeight / 2.0
            let valueBaseline: CGFloat = labelBaseline + buttonLabelFont.capHeight + labelSpacing
            
            for layout in layouts {
                draw(layout.value, x: x + layout.valueX, baseline: valueBaseline, context: context)
                draw(layout.label, x: x + layout.labelX, baseline: labelBaseline, context: context)
                x = x + layout.width + segmentSpacing
            }
            
            return true
        }
        
        image.isTemplate = true
        return image
    }
    
    /// Centers the label's ink under the value's digits, so a degree sign or unit after them never pulls it off center.
    /// - Note: The digits are monospaced and centered by their fixed width, not their ink, so the label stays put as the digits change. The label never changes, so its own ink is used.
    private static func segmentLayout(for segment: MenuBarButtonContent.Segment) -> SegmentLayout {
        let value: CTLine = makeLine(segment.value, font: buttonValueFont)
        let label: CTLine = makeLine(segment.label.localizedUppercase, font: buttonLabelFont)
        let digitsWidth: CGFloat = lineWidth(makeLine(digitsPrefix(of: segment.value), font: buttonValueFont))
        let labelInk: CGRect = inkBounds(of: label)
        let labelWidth: CGFloat = lineWidth(label)
        let labelStart: CGFloat = digitsWidth / 2.0 - labelInk.midX
        // Shifts both right when the label hangs past the value's leading edge.
        let shift: CGFloat = max(-labelStart, 0.0)
        let width: CGFloat = (max(lineWidth(value), labelStart + labelWidth) + shift).rounded(.up)
        return SegmentLayout(value: value, label: label, valueX: shift, labelX: labelStart + shift, width: width)
    }
    
    /// The value up to its last digit, such as "45" in "45°" or "318" in "318 K". Text with no digits, such as Off, is kept whole.
    private static func digitsPrefix(of text: String) -> String {
        guard let lastDigitIndex: String.Index = text.lastIndex(where: { $0.isNumber }) else { return text }
        return String(text[...lastDigitIndex])
    }
    
    private static func makeLine(_ text: String, font: NSFont) -> CTLine {
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
    }
    
    private static func inkBounds(of line: CTLine) -> CGRect {
        return CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    }
    
    private static func lineWidth(_ line: CTLine) -> CGFloat {
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }
    
    private static func draw(_ line: CTLine, x: CGFloat, baseline: CGFloat, context: CGContext) {
        context.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(line, context)
    }
    
    // MARK: - Menu
    private func currentReadingRows() -> MenuReadingRows {
        return MenuReadingRows.rows(snapshot: SensorMonitor.shared.snapshot, settings: FannySettingsManager.shared.settings)
    }
    
    /// Keeps the items VoiceOver is focused on when only values changed, and tells it to re-read the menu when they were replaced.
    private func refreshOpenMenu() {
        let rows: MenuReadingRows = currentReadingRows()
        
        if let lastReadingRows: MenuReadingRows = lastReadingRows, lastReadingRows.hasSameLayout(as: rows) {
            guard rows != lastReadingRows else { return }
            updateReadingItems(rows: rows)
        }
        else {
            rebuildMenu()
            NSAccessibility.post(element: menu, notification: .layoutChanged)
        }
    }
    
    /// Rebuilds the items for the current readings, which is safe while the menu is open.
    private func rebuildMenu() {
        let rows: MenuReadingRows = currentReadingRows()
        let contentWidth: CGFloat = MenuBarController.contentWidth(for: rows)
        
        lastReadingRows = rows
        readingContentWidth = contentWidth
        readingItems = []
        menu.removeAllItems()
        
        for row in rows.fanRows {
            addReadingItem(row: row, contentWidth: contentWidth)
        }
        
        if rows.temperatureRows.isEmpty == false {
            menu.addItem(NSMenuItem.separator())
            
            for row in rows.temperatureRows {
                addReadingItem(row: row, contentWidth: contentWidth)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        addActionItems(to: menu)
        menu.addItem(NSMenuItem.separator())
        
        let quitItem: NSMenuItem = NSMenuItem(title: String(localized: "Quit Fanny", comment: "Menu bar: quit menu item (keep app name)"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApplication.shared
        quitItem.image = NSImage(systemSymbol: .power, accessibilityDescription: nil)
        menu.addItem(quitItem)
    }
    
    /// Reading rows are disabled, so clicking one does nothing.
    private func addReadingItem(row: MenuReadingRows.Row, contentWidth: CGFloat) {
        let item: NSMenuItem = NSMenuItem(title: row.title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        let rowView: MenuReadingRowView = MenuReadingRowView(contentWidth: contentWidth)
        rowView.configure(row: row)
        item.view = rowView
        menu.addItem(item)
        readingItems.append(item)
    }
    
    private func updateReadingItems(rows: MenuReadingRows) {
        let allRows: [MenuReadingRows.Row] = rows.fanRows + rows.temperatureRows
        guard allRows.count == readingItems.count, MenuBarController.contentWidth(for: rows) <= readingContentWidth else {
            rebuildMenu()
            NSAccessibility.post(element: menu, notification: .layoutChanged)
            return
        }
        
        for (item, row) in zip(readingItems, allRows) {
            item.title = row.title
            (item.view as? MenuReadingRowView)?.configure(row: row)
        }
        
        lastReadingRows = rows
    }
    
    /// The widest title, spacing, and value, or the widest detail line, so every value lines up with the right edge of the rows.
    private static func contentWidth(for rows: MenuReadingRows) -> CGFloat {
        let font: NSFont = MenuReadingRowView.font
        let allRows: [MenuReadingRows.Row] = rows.fanRows + rows.temperatureRows
        let readingRows: [MenuReadingRows.Row] = allRows.filter({ $0.style == MenuReadingRows.Row.Style.reading })
        let titleWidth: CGFloat = readingRows.map({ textWidth($0.title, font: font) }).max() ?? 0.0
        let valueWidth: CGFloat = readingRows.map({ textWidth($0.value ?? ReadingFormatter.missingText, font: font) }).max() ?? 0.0
        let otherWidth: CGFloat = allRows.filter({ $0.style != MenuReadingRows.Row.Style.reading }).map({ textWidth($0.title, font: font) }).max() ?? 0.0
        return max(titleWidth + MenuReadingRowView.valueSpacing + valueWidth, otherWidth).rounded(.up)
    }
    
    private static func textWidth(_ text: String, font: NSFont) -> CGFloat {
        return NSAttributedString(string: text, attributes: [.font: font]).size().width
    }
    
    /// The menu bar actions for the floating window's right-click menu, without the readings it already shows or Quit.
    func makeContextMenu() -> NSMenu {
        let contextMenu: NSMenu = NSMenu()
        addActionItems(to: contextMenu)
        return contextMenu
    }
    
    /// Adds the actions below the readings, from the Floating Window toggle down to Settings, with Developer Menu above Settings when Option is held.
    private func addActionItems(to menu: NSMenu) {
        let floatingWindowItem: NSMenuItem = makeItem(title: String(localized: "Floating Window", comment: "Accessibility label of the floating window. Also the menu item and Settings pane that show or customize it."), symbol: .pip, action: #selector(toggleFloatingWindow))
        floatingWindowItem.state = FannySettingsManager.shared.settings.showsFloatingWindow ? .on : .off
        menu.addItem(floatingWindowItem)
        menu.addItem(NSMenuItem.separator())
        
        if let availableUpdate: AvailableUpdate = UpdateChecker.shared.availableUpdate {
            let title: String = String(localized: "Update Available (\(availableUpdate.version))", comment: "Menu: opens the GitHub page of a newer Fanny version. The argument is the version number.")
            menu.addItem(makeItem(title: title, symbol: .arrowDownCircle, action: #selector(openAvailableUpdate)))
        }
        
        if PositiveApp.isMenuItemAvailable {
            let positiveItem: NSMenuItem = NSMenuItem(title: String(localized: "Download Positive", comment: "Menu: opens the App Store page of Positive, the developer's other app (keep Positive)."), action: #selector(downloadPositive), keyEquivalent: "")
            positiveItem.target = self
            positiveItem.image = NSImage(named: PositiveApp.symbolName)
            menu.addItem(positiveItem)
        }
        
        // Only in the menu bar's menu.
        if menu === self.menu, showsDeveloperMenuItem {
            menu.addItem(makeItem(title: DeveloperMenuWindowController.windowTitle, symbol: .wrenchAndScrewdriver, action: #selector(openDeveloperMenu)))
        }
        
        menu.addItem(makeItem(title: String(localized: "Settings...", comment: "Menu: opens the Settings window."), symbol: .gearshape, action: #selector(openSettings), keyEquivalent: ","))
    }
    
    private func makeItem(title: String, symbol: SFSymbol, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item: NSMenuItem = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.image = NSImage(systemSymbol: symbol, accessibilityDescription: nil)
        return item
    }
    
    // MARK: - Actions
    @objc private func toggleFloatingWindow(_ sender: NSMenuItem) {
        trackAction("FloatingWindow", sender: sender)
        FannySettingsManager.shared.update({ $0.showsFloatingWindow = ($0.showsFloatingWindow == false) })
    }
    
    @objc private func openSettings(_ sender: NSMenuItem) {
        trackAction("Settings", sender: sender)
        SettingsWindowController.shared.show()
    }
    
    @objc private func openDeveloperMenu(_ sender: NSMenuItem) {
        trackAction("DeveloperMenu", sender: sender)
        DeveloperMenuWindowController.shared.show()
    }
    
    @objc private func openAvailableUpdate(_ sender: NSMenuItem) {
        trackAction("UpdateAvailable", sender: sender)
        UpdateChecker.shared.openAvailableUpdate()
    }
    
    @objc private func downloadPositive(_ sender: NSMenuItem) {
        trackAction("DownloadPositive", sender: sender)
        PositiveApp.openAppStore()
    }
    
    /// True for the status item's menu, false for the floating window's right-click menu.
    private func isFromMenuBar(_ sender: NSMenuItem) -> Bool {
        return sender.menu === menu
    }
    
    // MARK: - Analytics
    /// Items in the floating window's right-click menu are tracked apart from the menu bar's, as `floatingWindowMenu`.
    private func trackAction(_ name: String, sender: NSMenuItem) {
        let prefix: String = isFromMenuBar(sender) ? "menu" : "floatingWindowMenu"
        let event: PageViewEvent = PageViewEvent(title: "\(prefix)_\(name)")
        Analytics.shared.track(event: event)
    }
}

// MARK: - NSMenuDelegate
extension MenuBarController: NSMenuDelegate {
    
    /// Runs just before the menu opens, so the Option key is read once per opening.
    func menuNeedsUpdate(_ menu: NSMenu) {
        if isMenuOpen == false {
            showsDeveloperMenuItem = NSEvent.modifierFlags.contains(.option)
        }
        
        rebuildMenu()
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        SensorMonitor.shared.menuWillOpen()
    }
    
    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        SensorMonitor.shared.menuDidClose()
    }
}

// MARK: - SensorMonitorDelegate
extension MenuBarController: SensorMonitorDelegate {
    
    func sensorMonitor(_ monitor: SensorMonitor, didUpdateSnapshot snapshot: ReadingsSnapshot) {
        updateButton()
        
        if isMenuOpen {
            refreshOpenMenu()
        }
    }
}

// MARK: - FannySettingsManagerDelegate
extension MenuBarController: FannySettingsManagerDelegate {
    
    func fannySettingsManager(_ manager: FannySettingsManager, didUpdateSettings settings: FannySettings) {
        updateButton()
        
        if isMenuOpen {
            refreshOpenMenu()
        }
    }
}

// MARK: - UpdateCheckerDelegate
extension MenuBarController: UpdateCheckerDelegate {
    
    func updateCheckerDidUpdateStatus(_ checker: UpdateChecker) {
        guard isMenuOpen else { return }
        rebuildMenu()
        NSAccessibility.post(element: menu, notification: .layoutChanged)
    }
}
