//
//  FannyWidgetBundle.swift
//  fanny-macOS-widget-extension
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import WidgetKit
import SwiftUI

/// Every widget this extension vends.
@main
struct FannyWidgetBundle: WidgetBundle {
    
    var body: some Widget {
        ReadingsWidget()
    }
}
