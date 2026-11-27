//
//  ReadingsEntry.swift
//  fanny-macOS-widget-extension
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import WidgetKit

/// One moment of the widget: the snapshot the app saved and the settings to draw it with.
struct ReadingsEntry: TimelineEntry {
    
    let date: Date
    /// `nil` until the app saves its first read.
    let snapshot: ReadingsSnapshot?
    let settings: FannySettings
    /// Gallery and placeholder renders, which are not the user using the widget.
    let isPreview: Bool
    
    /// No snapshot at all reads as stale too, since only opening Fanny can fill the widget.
    var isStale: Bool {
        guard let snapshot: ReadingsSnapshot = snapshot else { return true }
        return snapshot.isStale(at: date)
    }
}
