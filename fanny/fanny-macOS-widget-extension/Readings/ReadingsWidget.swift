//
//  ReadingsWidget.swift
//  fanny-macOS-widget-extension
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import WidgetKit
import SwiftUI

/// Shows the fan speeds and the CPU and GPU temperatures the app last read.
struct ReadingsWidget: Widget {
    
    /// The app's name in every language.
    private static let configurationDisplayName: String = "Fanny"
    private static let configurationDescription: String = String(localized: "Fan speeds and CPU and GPU temperatures.", comment: "Widget gallery: what the widget shows")
    
    var body: some WidgetConfiguration {
        return StaticConfiguration(kind: ReadingsSnapshot.widgetKind, provider: ReadingsProvider()) { entry in
            ReadingsView(entry: entry)
        }
        .configurationDisplayName(ReadingsWidget.configurationDisplayName)
        .description(ReadingsWidget.configurationDescription)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}
