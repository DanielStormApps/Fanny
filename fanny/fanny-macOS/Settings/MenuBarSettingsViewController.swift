//
//  MenuBarSettingsViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout

/// The Menu Bar pane: which items the menu bar shows, and in what order after the Fanny icon.
final class MenuBarSettingsViewController: ViewController {
    
    private let settingsScrollView: SettingsScrollView = SettingsScrollView()
    private let tableScrollView: NSScrollView = NSScrollView()
    private let tableView: NSTableView = NSTableView()
    
    private var kinds: [MenuBarLayout.ItemKind] = []
    /// Temperatures turned off in Sensors, which the list notes on their rows.
    private var turnedOffKinds: [MenuBarLayout.ItemKind] = []
    private var tableHeightConstraint: NSLayoutConstraint?
    
    private static let pasteboardType: NSPasteboard.PasteboardType = NSPasteboard.PasteboardType("com.fannywidget.menuBarItem")
    private static let cellIdentifier: NSUserInterfaceItemIdentifier = NSUserInterfaceItemIdentifier("MenuBarItemCell")
    private static let rowHeight: CGFloat = 28.0
    private static let tableVerticalInset: CGFloat = 6.0
    
    // MARK: - View Cycle
    override func loadView() {
        view = settingsScrollView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analytics(title: "menuBar")
        setupItemsGroup()
        FannySettingsManager.shared.delegate.add(self)
        SensorMonitor.shared.delegate.add(self)
        reload()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        reload()
    }
    
    // MARK: - Setup
    private func setupItemsGroup() {
        let column: NSTableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MenuBarItemColumn"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .plain
        tableView.backgroundColor = NSColor.clear
        tableView.rowHeight = MenuBarSettingsViewController.rowHeight
        tableView.intercellSpacing = CGSize(width: 0.0, height: 0.0)
        tableView.selectionHighlightStyle = .none
        tableView.focusRingType = .none
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.draggingDestinationFeedbackStyle = .gap
        tableView.registerForDraggedTypes([MenuBarSettingsViewController.pasteboardType])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.setAccessibilityLabel(MenuBarSettingsViewController.listTitle)
        
        tableScrollView.documentView = tableView
        tableScrollView.drawsBackground = false
        tableScrollView.hasVerticalScroller = false
        tableScrollView.hasHorizontalScroller = false
        tableScrollView.verticalScrollElasticity = .none
        tableScrollView.automaticallyAdjustsContentInsets = false
        
        let containerView: NSView = NSView()
        containerView.addSubview(tableScrollView)
        let inset: CGFloat = MenuBarSettingsViewController.tableVerticalInset
        tableScrollView.autoPinEdgesToSuperviewEdges(with: NSEdgeInsets(top: inset, left: 4.0, bottom: inset, right: 12.0))
        tableHeightConstraint = tableScrollView.autoSetDimension(.height, toSize: MenuBarSettingsViewController.rowHeight)
        
        let group: SettingsGroupView = SettingsGroupView()
        group.addRow(containerView)
        settingsScrollView.addGroup(group, header: MenuBarSettingsViewController.listTitle, footer: String(localized: "Drag items to reorder them. Hover over the menu bar item to see every reading.", comment: "Settings footnote under the list of what the menu bar shows (keep Fanny)."))
    }
    
    // MARK: - Reload
    /// Rebuilds the rows only when the items or their order changed, so a checkbox keeps VoiceOver focus while values update.
    private func reload() {
        let settings: FannySettings = FannySettingsManager.shared.settings
        let updatedKinds: [MenuBarLayout.ItemKind] = settings.menuBarLayout.items(fanIDs: MenuBarSettingsViewController.currentFanIDs()).map({ $0.kind })
        let turnedOffKinds: [MenuBarLayout.ItemKind] = updatedKinds.filter({ MenuBarSettingsViewController.isTurnedOff($0, settings: settings) })
        
        guard updatedKinds != kinds || turnedOffKinds != self.turnedOffKinds else {
            reloadCheckboxes()
            return
        }
        
        kinds = updatedKinds
        self.turnedOffKinds = turnedOffKinds
        tableView.reloadData()
        tableHeightConstraint?.constant = max(CGFloat(kinds.count), 1.0) * MenuBarSettingsViewController.rowHeight
    }
    
    private func reloadCheckboxes() {
        for row in 0..<tableView.numberOfRows {
            guard
                row < kinds.count,
                let cellView: ItemCellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? ItemCellView
            else { continue }
            
            cellView.checkbox.state = isVisible(kinds[row]) ? .on : .off
        }
    }
    
    private static func currentFanIDs() -> [Int] {
        guard let snapshot: ReadingsSnapshot = SensorMonitor.shared.snapshot, snapshot.fanStatus == ReadingsSnapshot.FanStatus.fans else { return [] }
        return snapshot.fans.map({ $0.id })
    }
    
    private func isVisible(_ kind: MenuBarLayout.ItemKind) -> Bool {
        let items: [MenuBarLayout.Item] = FannySettingsManager.shared.settings.menuBarLayout.items(fanIDs: MenuBarSettingsViewController.currentFanIDs())
        return items.first(where: { $0.kind == kind })?.isVisible ?? false
    }
    
    private static func isTurnedOff(_ kind: MenuBarLayout.ItemKind, settings: FannySettings) -> Bool {
        let isTurnedOff: Bool
        
        switch kind {
        case .cpu:
            isTurnedOff = settings.showsCPUTemperature == false
        case .gpu:
            isTurnedOff = settings.showsGPUTemperature == false
        case .icon, .fastestFan, .fan:
            isTurnedOff = false
        }
        
        return isTurnedOff
    }
    
    // MARK: - Layout Changes
    /// Normalizes first, so a fan item that only exists once the fans are known can be edited.
    private func updateLayout(_ change: @escaping (inout MenuBarLayout) -> Void) {
        let fanIDs: [Int] = MenuBarSettingsViewController.currentFanIDs()
        FannySettingsManager.shared.update({ settings in
            var layout: MenuBarLayout = settings.menuBarLayout.normalized(fanIDs: fanIDs)
            change(&layout)
            settings.menuBarLayout = layout
        })
    }
    
    /// Moves an item one place up or down, for VoiceOver and the keyboard. The icon stays first.
    /// - Returns: `false` when it cannot move that way.
    @discardableResult
    private func move(_ kind: MenuBarLayout.ItemKind, by offset: Int) -> Bool {
        guard
            let index: Int = kinds.firstIndex(of: kind),
            index + offset >= 1,
            index + offset < kinds.count,
            kind != MenuBarLayout.ItemKind.icon
        else { return false }
        
        // Moving down means sitting before the item two places on, or at the end.
        let destinationIndex: Int = offset > 0 ? index + offset + 1 : index + offset
        move(kind, toIndex: destinationIndex)
        announceMove(of: kind, position: index + offset + 1, count: kinds.count)
        return true
    }
    
    /// The list reloads after a move, so VoiceOver hears where the item landed instead of losing its place silently.
    private func announceMove(of kind: MenuBarLayout.ItemKind, position: Int, count: Int) {
        let title: String = MenuBarSettingsViewController.title(for: kind)
        let announcement: String = String(localized: "\(title), position \(position) of \(count)", comment: "Spoken by VoiceOver after Move Up or Move Down in a reorderable Settings list, such as Fan 1, position 2 of 5. The first argument is the item, then its new place and how many items there are.")
        NSAccessibility.post(element: tableView, notification: .announcementRequested, userInfo: [.announcement: announcement, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
    
    private func move(_ kind: MenuBarLayout.ItemKind, toIndex destinationIndex: Int) {
        let destination: MenuBarLayout.ItemKind? = destinationIndex < kinds.count ? kinds[destinationIndex] : nil
        updateLayout({ $0.moveItem(kind, before: destination) })
        trackAction("menuBar_MoveItem")
    }
    
    // MARK: - Actions
    @objc private func checkboxChanged(_ sender: NSButton) {
        let row: Int = tableView.row(for: sender)
        guard row >= 0, row < kinds.count else { return }
        let kind: MenuBarLayout.ItemKind = kinds[row]
        let isOn: Bool = sender.state == .on
        
        // Tracked after the change, so the shared parameters carry the new value.
        updateLayout({ $0.setVisible(isOn, kind: kind) })
        trackAction("menuBar_Item")
    }
    
    @objc private func openSensorsSettings() {
        trackAction("menuBar_OpenSensors")
        SettingsWindowController.shared.show(pane: .sensors)
    }
    
    // MARK: - Helpers
    private static var listTitle: String {
        return String(localized: "Show in Menu Bar", comment: "Settings, Menu Bar: header and accessibility label of the list of what the menu bar item shows.")
    }
    
    static func title(for kind: MenuBarLayout.ItemKind) -> String {
        let title: String
        
        switch kind {
        case .icon:
            title = String(localized: "Fanny Icon", comment: "Settings list item: the menu bar shows the Fanny fan icon (keep Fanny).")
        case .fastestFan:
            title = String(localized: "Fastest Fan", comment: "Settings list item: the menu bar shows the speed of the fastest fan.")
        case .fan(let id):
            title = ReadingFormatter.fanName(id: id, settings: FannySettingsManager.shared.settings)
        case .cpu:
            title = String(localized: "CPU Temperature", comment: "Settings list item: the menu bar shows the CPU temperature.")
        case .gpu:
            title = String(localized: "GPU Temperature", comment: "Settings list item: the menu bar shows the GPU temperature.")
        }
        
        return title
    }
    
    // MARK: - Analytics
    private func trackAction(_ title: String) {
        let event: PageViewEvent = PageViewEvent(title: title)
        Analytics.shared.track(event: event)
    }
}

// MARK: - NSTableViewDataSource
extension MenuBarSettingsViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return kinds.count
    }
    
    /// The icon stays first, so it cannot be dragged.
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard row > 0, row < kinds.count else { return nil }
        let pasteboardItem: NSPasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(kinds[row].id, forType: MenuBarSettingsViewController.pasteboardType)
        return pasteboardItem
    }
    
    /// Items drop between rows, never above the icon.
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard
            draggedKind(from: info) != nil,
            dropOperation == .above,
            row >= 1
        else { return [] }
        
        return .move
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let kind: MenuBarLayout.ItemKind = draggedKind(from: info) else { return false }
        move(kind, toIndex: row)
        return true
    }
    
    private func draggedKind(from info: NSDraggingInfo) -> MenuBarLayout.ItemKind? {
        guard let value: String = info.draggingPasteboard.string(forType: MenuBarSettingsViewController.pasteboardType) else { return nil }
        return kinds.first(where: { $0.id == value })
    }
}

// MARK: - NSTableViewDelegate
extension MenuBarSettingsViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < kinds.count else { return nil }
        let kind: MenuBarLayout.ItemKind = kinds[row]
        
        let cellView: ItemCellView = (tableView.makeView(withIdentifier: MenuBarSettingsViewController.cellIdentifier, owner: self) as? ItemCellView) ?? ItemCellView()
        cellView.identifier = MenuBarSettingsViewController.cellIdentifier
        
        let isIcon: Bool = kind == MenuBarLayout.ItemKind.icon
        let note: String? = turnedOffKinds.contains(kind) ? String(localized: "Turned off in Sensors", comment: "Settings, Menu Bar and Floating Window: note beside the CPU or GPU item when that temperature is turned off in the Sensors pane.") : nil
        cellView.configure(title: MenuBarSettingsViewController.title(for: kind), isBold: false, isOn: isVisible(kind), note: note, isMovable: isIcon == false)
        cellView.checkbox.target = self
        cellView.checkbox.action = #selector(checkboxChanged(_:))
        cellView.checkbox.setAccessibilityCustomActions(isIcon ? [] : accessibilityActions(for: kind))
        cellView.noteButton.target = self
        cellView.noteButton.action = #selector(openSensorsSettings)
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
    
    /// VoiceOver cannot drag, so each movable row also offers Move Up and Move Down.
    private func accessibilityActions(for kind: MenuBarLayout.ItemKind) -> [NSAccessibilityCustomAction] {
        let moveUpAction: NSAccessibilityCustomAction = NSAccessibilityCustomAction(name: String(localized: "Move Up", comment: "VoiceOver action in a reorderable Settings list, such as the floating window's cards: moves an item up one place.")) { [weak self] in
            return self?.move(kind, by: -1) ?? false
        }
        let moveDownAction: NSAccessibilityCustomAction = NSAccessibilityCustomAction(name: String(localized: "Move Down", comment: "VoiceOver action in a reorderable Settings list, such as the floating window's cards: moves an item down one place.")) { [weak self] in
            return self?.move(kind, by: 1) ?? false
        }
        
        return [moveUpAction, moveDownAction]
    }
}

// MARK: - FannySettingsManagerDelegate
extension MenuBarSettingsViewController: FannySettingsManagerDelegate {
    
    func fannySettingsManager(_ manager: FannySettingsManager, didUpdateSettings settings: FannySettings) {
        reload()
    }
}

// MARK: - SensorMonitorDelegate
extension MenuBarSettingsViewController: SensorMonitorDelegate {
    
    /// The fan items appear once the first read finds the fans.
    func sensorMonitor(_ monitor: SensorMonitor, didUpdateSnapshot snapshot: ReadingsSnapshot) {
        reload()
    }
}
