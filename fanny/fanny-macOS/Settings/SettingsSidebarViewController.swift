//
//  SettingsSidebarViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout

// MARK: - SettingsSidebarViewControllerDelegate
/// Listener told when the user picks a pane in the sidebar.
protocol SettingsSidebarViewControllerDelegate: AnyObject {
    func settingsSidebarViewController(_ viewController: SettingsSidebarViewController, didSelect pane: SettingsPane)
}

// MARK: - SettingsSidebarViewController
/// The source list of panes on the left of the Settings window.
final class SettingsSidebarViewController: ViewController {
    
    weak var delegate: SettingsSidebarViewControllerDelegate?
    
    private let scrollView: NSScrollView = NSScrollView()
    private let tableView: NSTableView = NSTableView()
    private let panes: [SettingsPane] = SettingsPane.allCases
    
    private static let cellIdentifier: NSUserInterfaceItemIdentifier = NSUserInterfaceItemIdentifier("SettingsSidebarCell")
    private static let rowHeight: CGFloat = 32.0
    
    // MARK: - View Cycle
    override func loadView() {
        view = NSView(frame: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 400.0))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analyticsIsEnabled = false
        setupTableView()
    }
    
    // MARK: - Setup
    private func setupTableView() {
        let column: NSTableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SettingsSidebarColumn"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .sourceList
        tableView.rowHeight = SettingsSidebarViewController.rowHeight
        tableView.allowsEmptySelection = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.setAccessibilityLabel(String(localized: "Settings", comment: "Accessibility label of the Settings sidebar list."))
        
        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        view.addSubview(scrollView)
        scrollView.autoPinEdgesToSuperviewEdges()
    }
    
    // MARK: - Selection
    /// Selects a pane. The delegate is still told, so it must ignore the pane it already shows.
    func select(_ pane: SettingsPane) {
        guard let index: Int = panes.firstIndex(of: pane) else { return }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    }
}

// MARK: - NSTableViewDataSource
extension SettingsSidebarViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return panes.count
    }
}

// MARK: - NSTableViewDelegate
extension SettingsSidebarViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let pane: SettingsPane = panes[row]
        let cell: NSTableCellView
        
        if let reusedCell: NSTableCellView = tableView.makeView(withIdentifier: SettingsSidebarViewController.cellIdentifier, owner: self) as? NSTableCellView {
            cell = reusedCell
        }
        else {
            cell = NSTableCellView()
            cell.identifier = SettingsSidebarViewController.cellIdentifier
            
            let imageView: NSImageView = NSImageView()
            imageView.imageScaling = .scaleProportionallyDown
            cell.addSubview(imageView)
            cell.imageView = imageView
            imageView.hideFromAccessibility()
            imageView.autoPinEdge(toSuperviewEdge: .leading, withInset: 4.0)
            imageView.autoAlignAxis(toSuperviewAxis: .horizontal)
            imageView.autoSetDimensions(to: CGSize(width: 20.0, height: 20.0))
            
            let textField: NSTextField = NSTextField(labelWithString: "")
            textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            textField.lineBreakMode = .byTruncatingTail
            cell.addSubview(textField)
            cell.textField = textField
            textField.autoPinEdge(.leading, to: .trailing, of: imageView, withOffset: 8.0)
            textField.autoPinEdge(toSuperviewEdge: .trailing, withInset: 4.0)
            textField.autoAlignAxis(toSuperviewAxis: .horizontal)
        }
        
        cell.textField?.stringValue = pane.title
        cell.imageView?.image = NSImage(systemSymbol: pane.symbol, accessibilityDescription: nil)
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row: Int = tableView.selectedRow
        guard row >= 0, row < panes.count else { return }
        delegate?.settingsSidebarViewController(self, didSelect: panes[row])
    }
}
