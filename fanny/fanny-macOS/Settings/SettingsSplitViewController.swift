//
//  SettingsSplitViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

// MARK: - SettingsSplitViewControllerDelegate
/// Listener told when the visible pane changes.
protocol SettingsSplitViewControllerDelegate: AnyObject {
    func settingsSplitViewController(_ viewController: SettingsSplitViewController, didShow pane: SettingsPane)
}

// MARK: - SettingsSplitViewController
/// The sidebar and the pane beside it, laid out like System Settings.
final class SettingsSplitViewController: NSSplitViewController {
    
    weak var settingsDelegate: SettingsSplitViewControllerDelegate?
    
    private let sidebarViewController: SettingsSidebarViewController = SettingsSidebarViewController()
    private(set) var currentPane: SettingsPane = SettingsPane.restored()
    
    private static let sidebarWidth: CGFloat = 200.0
    private static let paneMinimumWidth: CGFloat = 500.0
    
    // MARK: - View Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        splitView.autosaveName = "SettingsSplitView"
        
        let sidebarItem: NSSplitViewItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = SettingsSplitViewController.sidebarWidth
        sidebarItem.maximumThickness = SettingsSplitViewController.sidebarWidth
        addSplitViewItem(sidebarItem)
        
        sidebarViewController.delegate = self
        show(currentPane)
        sidebarViewController.select(currentPane)
    }
    
    // MARK: - Select
    /// Shows a pane and moves the sidebar selection to it.
    func select(_ pane: SettingsPane) {
        loadViewIfNeeded()
        guard pane != currentPane else { return }
        show(pane)
        sidebarViewController.select(pane)
    }
    
    // MARK: - Panes
    private func show(_ pane: SettingsPane) {
        // Ends any edit first, so a typed but unsaved value, such as a fan name, is saved before its pane goes away.
        view.window?.makeFirstResponder(nil)
        
        if splitViewItems.count > 1 {
            removeSplitViewItem(splitViewItems[1])
        }
        
        let paneItem: NSSplitViewItem = NSSplitViewItem(viewController: pane.makeViewController())
        paneItem.minimumThickness = SettingsSplitViewController.paneMinimumWidth
        addSplitViewItem(paneItem)
        
        currentPane = pane
        pane.saveAsLastPane()
        settingsDelegate?.settingsSplitViewController(self, didShow: pane)
    }
}

// MARK: - SettingsSidebarViewControllerDelegate
extension SettingsSplitViewController: SettingsSidebarViewControllerDelegate {
    
    func settingsSidebarViewController(_ viewController: SettingsSidebarViewController, didSelect pane: SettingsPane) {
        guard pane != currentPane else { return }
        show(pane)
    }
}
