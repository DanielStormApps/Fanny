//
//  FloatingWindowSettingsViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout
import SFSafeSymbols

/// The Floating Window pane: whether it shows, its layout, and which cards and stats it shows in what order.
final class FloatingWindowSettingsViewController: ViewController {
    
    /// An outline row: a card, or one stat of a card. Outline views need objects, so rows are classes.
    private final class Item: NSObject {
        let kind: FloatingWindowLayout.CardKind
        /// `nil` for a card row.
        let stat: FloatingWindowLayout.Stat?
        let children: [Item]
        
        init(kind: FloatingWindowLayout.CardKind, stat: FloatingWindowLayout.Stat?, children: [Item]) {
            self.kind = kind
            self.stat = stat
            self.children = children
        }
        
        /// What a drag carries, such as `cpu` for a card or `cpu/cpuDie` for a stat.
        var pasteboardValue: String {
            return stat.map({ "\(kind.id)/\($0.rawValue)" }) ?? kind.id
        }
    }
    
    private let settingsScrollView: SettingsScrollView = SettingsScrollView()
    private let showSwitch: NSSwitch = NSSwitch()
    private let orientationPopUpButton: NSPopUpButton = NSPopUpButton(frame: CGRect.zero, pullsDown: false)
    private let outlineScrollView: NSScrollView = NSScrollView()
    private let outlineView: NSOutlineView = NSOutlineView()
    
    private var items: [Item] = []
    /// Cards whose temperature is turned off in Sensors, which the list notes on their rows.
    private var turnedOffKinds: [FloatingWindowLayout.CardKind] = []
    private var outlineHeightConstraint: NSLayoutConstraint?
    
    private static let pasteboardType: NSPasteboard.PasteboardType = NSPasteboard.PasteboardType("com.fannywidget.floatingWindowItem")
    private static let cellIdentifier: NSUserInterfaceItemIdentifier = NSUserInterfaceItemIdentifier("FloatingWindowItemCell")
    private static let rowHeight: CGFloat = 28.0
    private static let outlineVerticalInset: CGFloat = 6.0
    
    // MARK: - View Cycle
    override func loadView() {
        view = settingsScrollView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analytics(title: "floatingWindow")
        setupGeneralGroup()
        setupCardsGroup()
        FannySettingsManager.shared.delegate.add(self)
        SensorMonitor.shared.delegate.add(self)
        reload()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        reload()
    }
    
    // MARK: - Setup
    private func setupGeneralGroup() {
        showSwitch.target = self
        showSwitch.action = #selector(showChanged)
        
        for orientation in FloatingWindowLayout.Orientation.allCases {
            orientationPopUpButton.addItem(withTitle: FloatingWindowSettingsViewController.title(for: orientation))
            orientationPopUpButton.lastItem?.image = NSImage(systemSymbol: FloatingWindowSettingsViewController.symbol(for: orientation), accessibilityDescription: nil)
        }
        
        orientationPopUpButton.target = self
        orientationPopUpButton.action = #selector(orientationChanged)
        
        let group: SettingsGroupView = SettingsGroupView()
        group.addRow(SettingsRowView(title: String(localized: "Show Floating Window", comment: "Settings switch: shows the small floating window that stays above other windows."), control: showSwitch))
        group.addRow(SettingsRowView(title: String(localized: "Layout", comment: "Settings pop-up: whether the floating window's cards sit in a row (Horizontal) or a column (Vertical)."), control: orientationPopUpButton))
        settingsScrollView.addGroup(group, footer: String(localized: "Drag the floating window anywhere. Hover over it to close it, or right-click it for more.", comment: "Settings footnote under the floating window options."))
    }
    
    private func setupCardsGroup() {
        let column: NSTableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FloatingWindowItemColumn"))
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.style = .plain
        outlineView.backgroundColor = NSColor.clear
        outlineView.rowHeight = FloatingWindowSettingsViewController.rowHeight
        outlineView.intercellSpacing = CGSize(width: 0.0, height: 0.0)
        outlineView.selectionHighlightStyle = .none
        outlineView.focusRingType = .none
        outlineView.indentationPerLevel = 18.0
        outlineView.autoresizesOutlineColumn = false
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outlineView.draggingDestinationFeedbackStyle = .gap
        outlineView.registerForDraggedTypes([FloatingWindowSettingsViewController.pasteboardType])
        outlineView.setDraggingSourceOperationMask(.move, forLocal: true)
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.setAccessibilityLabel(String(localized: "Cards", comment: "Settings, Floating Window: header and accessibility label of the list of cards and their readings."))
        
        outlineScrollView.documentView = outlineView
        outlineScrollView.drawsBackground = false
        outlineScrollView.hasVerticalScroller = false
        outlineScrollView.hasHorizontalScroller = false
        outlineScrollView.verticalScrollElasticity = .none
        outlineScrollView.automaticallyAdjustsContentInsets = false
        
        let containerView: NSView = NSView()
        containerView.addSubview(outlineScrollView)
        let inset: CGFloat = FloatingWindowSettingsViewController.outlineVerticalInset
        outlineScrollView.autoPinEdgesToSuperviewEdges(with: NSEdgeInsets(top: inset, left: 4.0, bottom: inset, right: 12.0))
        outlineHeightConstraint = outlineScrollView.autoSetDimension(.height, toSize: FloatingWindowSettingsViewController.rowHeight)
        
        let group: SettingsGroupView = SettingsGroupView()
        group.addRow(containerView)
        settingsScrollView.addGroup(group, header: String(localized: "Cards", comment: "Settings, Floating Window: header and accessibility label of the list of cards and their readings."), footer: String(localized: "Drag cards and readings to reorder them.", comment: "Settings footnote under the floating window's card list."))
    }
    
    // MARK: - Reload
    private func reload() {
        let settings: FannySettings = FannySettingsManager.shared.settings
        showSwitch.state = settings.showsFloatingWindow ? .on : .off
        orientationPopUpButton.selectItem(at: FloatingWindowLayout.Orientation.allCases.firstIndex(of: settings.floatingWindowLayout.orientation) ?? 0)
        reloadItems()
    }
    
    /// Rebuilds the rows only when the cards or their order changed, so a checkbox keeps VoiceOver focus while values update.
    private func reloadItems() {
        let cards: [FloatingWindowLayout.Card] = FannySettingsManager.shared.settings.floatingWindowLayout.cards(fanIDs: FloatingWindowSettingsViewController.currentFanIDs())
        let updatedItems: [Item] = cards.map({ card in
            let children: [Item] = card.stats.map({ Item(kind: card.kind, stat: $0.stat, children: []) })
            return Item(kind: card.kind, stat: nil, children: children)
        })
        
        let settings: FannySettings = FannySettingsManager.shared.settings
        let turnedOffKinds: [FloatingWindowLayout.CardKind] = cards.map({ $0.kind }).filter({ FloatingWindowContent.isTurnedOff($0, settings: settings) })
        
        let hasSameRows: Bool = updatedItems.map({ FloatingWindowSettingsViewController.signature(of: $0) }) == items.map({ FloatingWindowSettingsViewController.signature(of: $0) }) && turnedOffKinds == self.turnedOffKinds
        guard hasSameRows == false else {
            reloadCheckboxes()
            return
        }
        
        items = updatedItems
        self.turnedOffKinds = turnedOffKinds
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
        outlineHeightConstraint?.constant = max(CGFloat(outlineView.numberOfRows), 1.0) * FloatingWindowSettingsViewController.rowHeight
    }
    
    private func reloadCheckboxes() {
        for row in 0..<outlineView.numberOfRows {
            guard
                let item: Item = outlineView.item(atRow: row) as? Item,
                let cellView: ItemCellView = outlineView.view(atColumn: 0, row: row, makeIfNecessary: false) as? ItemCellView
            else { continue }
            
            cellView.checkbox.state = isVisible(item) ? .on : .off
        }
    }
    
    private static func signature(of item: Item) -> [String] {
        return [item.pasteboardValue] + item.children.map({ $0.pasteboardValue })
    }
    
    private static func currentFanIDs() -> [Int] {
        guard let snapshot: ReadingsSnapshot = SensorMonitor.shared.snapshot, snapshot.fanStatus == ReadingsSnapshot.FanStatus.fans else { return [] }
        return snapshot.fans.map({ $0.id })
    }
    
    private func isVisible(_ item: Item) -> Bool {
        // Normalized like the list and the window, so a fan card not saved yet shows its default readings checked.
        let layout: FloatingWindowLayout = FannySettingsManager.shared.settings.floatingWindowLayout.normalized(fanIDs: FloatingWindowSettingsViewController.currentFanIDs())
        guard let card: FloatingWindowLayout.Card = layout.cards.first(where: { $0.kind == item.kind }) else { return item.stat == nil }
        
        let isVisible: Bool
        
        if let stat: FloatingWindowLayout.Stat = item.stat {
            isVisible = card.stats.first(where: { $0.stat == stat })?.isVisible ?? false
        }
        else {
            isVisible = card.isVisible
        }
        
        return isVisible
    }
    
    // MARK: - Layout Changes
    /// Normalizes first, so a fan card that only exists once the fans are known can be edited.
    private func updateLayout(_ change: @escaping (inout FloatingWindowLayout) -> Void) {
        let fanIDs: [Int] = FloatingWindowSettingsViewController.currentFanIDs()
        FannySettingsManager.shared.update({ settings in
            var layout: FloatingWindowLayout = settings.floatingWindowLayout.normalized(fanIDs: fanIDs)
            change(&layout)
            settings.floatingWindowLayout = layout
        })
    }
    
    /// Moves an item one place up or down among its siblings, for VoiceOver and the keyboard.
    /// - Returns: `false` when it is already first or last.
    @discardableResult
    private func move(_ item: Item, by offset: Int) -> Bool {
        let siblings: [Item] = siblings(of: item)
        guard
            let index: Int = siblings.firstIndex(of: item),
            index + offset >= 0,
            index + offset < siblings.count
        else { return false }
        
        // Moving down means sitting before the item two places on, or at the end.
        let destinationIndex: Int = offset > 0 ? index + offset + 1 : index + offset
        move(item, toSiblingIndex: destinationIndex)
        announceMove(of: item, position: index + offset + 1, count: siblings.count)
        return true
    }
    
    private func move(_ item: Item, toSiblingIndex destinationIndex: Int) {
        let siblings: [Item] = siblings(of: item)
        let destination: Item? = destinationIndex < siblings.count ? siblings[destinationIndex] : nil
        
        if let stat: FloatingWindowLayout.Stat = item.stat {
            updateLayout({ $0.moveStat(stat, before: destination?.stat, kind: item.kind) })
            trackAction("floatingWindow_MoveStat")
        }
        else {
            updateLayout({ $0.moveCard(item.kind, before: destination?.kind) })
            trackAction("floatingWindow_MoveCard")
        }
    }
    
    /// The list reloads after a move, so VoiceOver hears where the item landed instead of losing its place silently.
    private func announceMove(of item: Item, position: Int, count: Int) {
        let settings: FannySettings = FannySettingsManager.shared.settings
        let title: String = item.stat.map({ FloatingWindowContent.title(for: $0) }) ?? FloatingWindowContent.title(for: item.kind, settings: settings)
        let announcement: String = String(localized: "\(title), position \(position) of \(count)", comment: "Spoken by VoiceOver after Move Up or Move Down in a reorderable Settings list, such as Fan 1, position 2 of 5. The first argument is the item, then its new place and how many items there are.")
        NSAccessibility.post(element: outlineView, notification: .announcementRequested, userInfo: [.announcement: announcement, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
    
    private func siblings(of item: Item) -> [Item] {
        guard item.stat != nil else { return items }
        return items.first(where: { $0.kind == item.kind })?.children ?? []
    }
    
    // MARK: - Actions
    @objc private func showChanged() {
        let isOn: Bool = showSwitch.state == .on
        FannySettingsManager.shared.update({ $0.showsFloatingWindow = isOn })
        trackAction("floatingWindow_Show")
    }
    
    @objc private func orientationChanged() {
        let index: Int = orientationPopUpButton.indexOfSelectedItem
        let orientations: [FloatingWindowLayout.Orientation] = FloatingWindowLayout.Orientation.allCases
        guard index >= 0, index < orientations.count else { return }
        let orientation: FloatingWindowLayout.Orientation = orientations[index]
        
        updateLayout({ $0.orientation = orientation })
        trackAction("floatingWindow_Layout")
    }
    
    @objc private func checkboxChanged(_ sender: NSButton) {
        let row: Int = outlineView.row(for: sender)
        guard let item: Item = outlineView.item(atRow: row) as? Item else { return }
        let isOn: Bool = sender.state == .on
        
        if let stat: FloatingWindowLayout.Stat = item.stat {
            updateLayout({ $0.setStatVisible(isOn, stat: stat, kind: item.kind) })
            trackAction("floatingWindow_Stat")
        }
        else {
            updateLayout({ $0.setCardVisible(isOn, kind: item.kind) })
            trackAction("floatingWindow_Card")
        }
    }
    
    @objc private func openSensorsSettings() {
        trackAction("floatingWindow_OpenSensors")
        SettingsWindowController.shared.show(pane: .sensors)
    }
    
    // MARK: - Helpers
    private static var turnedOffNote: String {
        return String(localized: "Turned off in Sensors", comment: "Settings, Menu Bar and Floating Window: note beside the CPU or GPU item when that temperature is turned off in the Sensors pane.")
    }
    
    /// Pictures the cards in a row or a column, so the choice reads at a glance.
    private static func symbol(for orientation: FloatingWindowLayout.Orientation) -> SFSymbol {
        let symbol: SFSymbol
        
        switch orientation {
        case .horizontal:
            symbol = .insetFilledLeftthirdMiddlethirdRightthirdRectangle
        case .vertical:
            symbol = .insetFilledTopthirdMiddlethirdBottomthirdRectangle
        }
        
        return symbol
    }
    
    private static func title(for orientation: FloatingWindowLayout.Orientation) -> String {
        let title: String
        
        switch orientation {
        case .horizontal:
            title = String(localized: "Horizontal", comment: "Settings pop-up item: the floating window's cards sit in a row.")
        case .vertical:
            title = String(localized: "Vertical", comment: "Settings pop-up item: the floating window's cards sit in a column.")
        }
        
        return title
    }
    
    // MARK: - Analytics
    private func trackAction(_ title: String) {
        let event: PageViewEvent = PageViewEvent(title: title)
        Analytics.shared.track(event: event)
    }
}

// MARK: - NSOutlineViewDataSource
extension FloatingWindowSettingsViewController: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return (item as? Item)?.children.count ?? items.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return (item as? Item)?.children[index] ?? items[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return ((item as? Item)?.children.isEmpty ?? true) == false
    }
    
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let item: Item = item as? Item else { return nil }
        let pasteboardItem: NSPasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(item.pasteboardValue, forType: FloatingWindowSettingsViewController.pasteboardType)
        return pasteboardItem
    }
    
    /// Cards move among cards, and a stat moves only within its own card.
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard
            let draggedItem: Item = draggedItem(from: info),
            index != NSOutlineViewDropOnItemIndex
        else { return [] }
        
        let targetItem: Item? = item as? Item
        let isValid: Bool
        
        if draggedItem.stat == nil {
            isValid = targetItem == nil
        }
        else {
            isValid = targetItem?.stat == nil && targetItem?.kind == draggedItem.kind
        }
        
        return isValid ? .move : []
    }
    
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let draggedItem: Item = draggedItem(from: info) else { return false }
        move(draggedItem, toSiblingIndex: index)
        return true
    }
    
    private func draggedItem(from info: NSDraggingInfo) -> Item? {
        guard let value: String = info.draggingPasteboard.string(forType: FloatingWindowSettingsViewController.pasteboardType) else { return nil }
        return items.flatMap({ [$0] + $0.children }).first(where: { $0.pasteboardValue == value })
    }
}

// MARK: - NSOutlineViewDelegate
extension FloatingWindowSettingsViewController: NSOutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let item: Item = item as? Item else { return nil }
        
        let cellView: ItemCellView = (outlineView.makeView(withIdentifier: FloatingWindowSettingsViewController.cellIdentifier, owner: self) as? ItemCellView) ?? ItemCellView()
        cellView.identifier = FloatingWindowSettingsViewController.cellIdentifier
        
        let title: String = item.stat.map({ FloatingWindowContent.title(for: $0) }) ?? FloatingWindowContent.title(for: item.kind, settings: FannySettingsManager.shared.settings)
        let isTurnedOff: Bool = item.stat == nil && turnedOffKinds.contains(item.kind)
        cellView.configure(title: title, isBold: item.stat == nil, isOn: isVisible(item), note: isTurnedOff ? FloatingWindowSettingsViewController.turnedOffNote : nil)
        cellView.checkbox.target = self
        cellView.checkbox.action = #selector(checkboxChanged(_:))
        cellView.checkbox.setAccessibilityCustomActions(accessibilityActions(for: item))
        // Every card has the same readings, so VoiceOver also hears which card a reading belongs to. Reused cells are reset.
        if item.stat != nil {
            let cardTitle: String = FloatingWindowContent.title(for: item.kind, settings: FannySettingsManager.shared.settings)
            cellView.checkbox.setAccessibilityLabel(String(localized: "\(cardTitle) \(title)", comment: "Spoken by VoiceOver for a reading's checkbox in Settings, Floating Window, such as Fan 1 Speed. The first argument is the card, such as Fan 1 or CPU, the second the reading, such as Speed."))
        }
        else {
            cellView.checkbox.setAccessibilityLabel(nil)
        }
        cellView.noteButton.target = self
        cellView.noteButton.action = #selector(openSensorsSettings)
        return cellView
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return false
    }
    
    /// The list stays fully expanded, since its height is sized to every row.
    func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        return false
    }
    
    /// VoiceOver cannot drag, so each row also offers Move Up and Move Down.
    private func accessibilityActions(for item: Item) -> [NSAccessibilityCustomAction] {
        let moveUpAction: NSAccessibilityCustomAction = NSAccessibilityCustomAction(name: String(localized: "Move Up", comment: "VoiceOver action in a reorderable Settings list, such as the floating window's cards: moves an item up one place.")) { [weak self] in
            return self?.move(item, by: -1) ?? false
        }
        let moveDownAction: NSAccessibilityCustomAction = NSAccessibilityCustomAction(name: String(localized: "Move Down", comment: "VoiceOver action in a reorderable Settings list, such as the floating window's cards: moves an item down one place.")) { [weak self] in
            return self?.move(item, by: 1) ?? false
        }
        
        return [moveUpAction, moveDownAction]
    }
}

// MARK: - FannySettingsManagerDelegate
extension FloatingWindowSettingsViewController: FannySettingsManagerDelegate {
    
    func fannySettingsManager(_ manager: FannySettingsManager, didUpdateSettings settings: FannySettings) {
        reload()
    }
}

// MARK: - SensorMonitorDelegate
extension FloatingWindowSettingsViewController: SensorMonitorDelegate {
    
    /// The fan cards appear once the first read finds the fans.
    func sensorMonitor(_ monitor: SensorMonitor, didUpdateSnapshot snapshot: ReadingsSnapshot) {
        reloadItems()
    }
}

// MARK: - ItemCellView
/// A row of a reorderable settings list: a checkbox with the item's name, and a handle that shows the row can be dragged.
final class ItemCellView: NSTableCellView {
    
    let checkbox: NSButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    /// A link to the Sensors pane, where a turned off temperature can be turned back on.
    let noteButton: NoteLinkButton = NoteLinkButton()
    private let handleImageView: NSImageView = NSImageView()
    
    // MARK: - Init
    init() {
        super.init(frame: CGRect.zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setup() {
        addSubview(checkbox)
        checkbox.autoPinEdge(toSuperviewEdge: .leading)
        checkbox.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        handleImageView.image = NSImage(systemSymbol: .line3Horizontal, accessibilityDescription: nil)
        handleImageView.contentTintColor = NSColor.tertiaryLabelColor
        handleImageView.hideFromAccessibility()
        addSubview(handleImageView)
        handleImageView.autoPinEdge(toSuperviewEdge: .trailing)
        handleImageView.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        noteButton.isBordered = false
        noteButton.setAccessibilityRole(.link)
        noteButton.setAccessibilityHelp(String(localized: "Opens a Settings pane", comment: "Accessibility hint: a link that switches to another pane of the Fanny settings window."))
        addSubview(noteButton)
        noteButton.autoPinEdge(.leading, to: .trailing, of: checkbox, withOffset: 8.0)
        // The note is smaller than the title, so it sits on the title's baseline rather than its center.
        noteButton.autoAlignAxis(.lastBaseline, toSameAxisOf: checkbox)
        handleImageView.autoPinEdge(.leading, to: .trailing, of: noteButton, withOffset: 8.0, relation: .greaterThanOrEqual)
    }
    
    /// - Parameter isBold: Sets a parent row, such as a card, apart from its children.
    /// - Parameter note: A link shown after the title, such as when the item's temperature is turned off.
    /// - Parameter isMovable: `false` hides the drag handle, for a row that always stays in place.
    func configure(title: String, isBold: Bool, isOn: Bool, note: String?, isMovable: Bool = true) {
        checkbox.title = title
        checkbox.font = isBold ? NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold) : NSFont.systemFont(ofSize: NSFont.systemFontSize)
        checkbox.state = isOn ? .on : .off
        handleImageView.isHidden = isMovable == false
        noteButton.isHidden = note == nil
        noteButton.attributedTitle = NSAttributedString(string: note ?? "", attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue,
                                                                                        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                                                                                        .foregroundColor: NSColor.linkColor])
        noteButton.setAccessibilityLabel(note)
    }
}

// MARK: - NoteLinkButton
/// A link-styled button with the pointing hand cursor.
final class NoteLinkButton: NSButton {
    
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: NSCursor.pointingHand)
    }
}
