//
//  DeveloperMenuSplitViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/25/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

/// The Developer Menu's sidebar and the pane beside it, like the Settings window.
final class DeveloperMenuSplitViewController: NSSplitViewController {
    
    private let sidebarViewController: DeveloperMenuSidebarViewController = DeveloperMenuSidebarViewController()
    private var currentPane: DeveloperMenuPane = DeveloperMenuPane.logs
    
    private static let sidebarWidth: CGFloat = 200.0
    private static let paneMinimumWidth: CGFloat = 500.0
    
    // MARK: - View Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        splitView.autosaveName = "DeveloperMenuSplitView"
        
        let sidebarItem: NSSplitViewItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = DeveloperMenuSplitViewController.sidebarWidth
        sidebarItem.maximumThickness = DeveloperMenuSplitViewController.sidebarWidth
        addSplitViewItem(sidebarItem)
        
        sidebarViewController.delegate = self
        show(currentPane)
        sidebarViewController.select(currentPane)
    }
    
    // MARK: - Panes
    private func show(_ pane: DeveloperMenuPane) {
        if splitViewItems.count > 1 {
            removeSplitViewItem(splitViewItems[1])
        }
        
        let paneItem: NSSplitViewItem = NSSplitViewItem(viewController: pane.makeViewController())
        paneItem.minimumThickness = DeveloperMenuSplitViewController.paneMinimumWidth
        addSplitViewItem(paneItem)
        currentPane = pane
    }
}

// MARK: - DeveloperMenuSidebarViewControllerDelegate
extension DeveloperMenuSplitViewController: DeveloperMenuSidebarViewControllerDelegate {
    
    func developerMenuSidebarViewController(_ viewController: DeveloperMenuSidebarViewController, didSelect pane: DeveloperMenuPane) {
        guard pane != currentPane else { return }
        show(pane)
    }
}
