//
//  AnalyticsBridge.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A connection between `Analytics` and an analytics service.
protocol AnalyticsBridge: AnyObject {
    init(trackingIDs: [String])
    func trackEvent(_ event: AnalyticsEvent)
    /// Starts or stops the service's own collection, including anything it sends without an event from us.
    func setEnabled(_ isEnabled: Bool)
}
