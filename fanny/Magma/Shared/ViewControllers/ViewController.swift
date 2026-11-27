//
//  ViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

/// The base view controller that tracks a page view when it appears.
class ViewController: NSViewController {
    
    var analyticsIsEnabled: Bool = true
    private(set) var analyticsTitle: String?
    
    // MARK: - View Cycle
    override func viewDidAppear() {
        super.viewDidAppear()
        trackPageViewEvent()
    }
    
    // MARK: - Analytics
    func analytics(title: String) {
        analyticsTitle = title
    }
    
    func trackPageViewEvent() {
        guard
            analyticsIsEnabled,
            let title: String = analyticsTitle
        else { return }
        
        let event: PageViewEvent = PageViewEvent(title: title)
        Analytics.shared.track(event: event)
    }
}
