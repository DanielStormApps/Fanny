//
//  ReadingsView.swift
//  fanny-macOS-widget-extension
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import AppKit
import WidgetKit
import SwiftUI
import SFSafeSymbols

/// Draws the temperatures and fan speeds in each size, with a live age in the footer, dimmed once the snapshot is stale.
struct ReadingsView: View {
    
    /// One temperature the settings show.
    private struct TemperatureItem: Identifiable {
        let id: String
        let title: String
        let symbol: SFSymbol
        let reading: TemperatureReading?
        /// An invisible stand-in that holds the place of a temperature turned off.
        var isPlaceholder: Bool = false
    }
    
    /// One step in the temperature row's shrinking, from the full size down.
    private struct TemperatureFontSizes {
        let title: CGFloat
        let value: CGFloat
    }
    
    private static let contentPadding: CGFloat = 4.0
    private static let spacing: CGFloat = 8.0
    private static let smallSpacing: CGFloat = 2.0
    /// Tight, so a symbol reads as part of the label after it rather than a separate item.
    private static let symbolLabelSpacing: CGFloat = 2.0
    private static let temperatureSpacing: CGFloat = 16.0
    // The large fan speeds have no matching text style, so they keep fixed display sizes.
    private static let smallFanFontSize: CGFloat = 34.0
    private static let mediumFanFontSize: CGFloat = 30.0
    private static let largeFanFontSize: CGFloat = 30.0
    private static let footerFontSize: CGFloat = 9.0
    /// Text sits above its line's descent, so the footer moves down by about that much to look as far from the bottom edge as from the side.
    private static let footerBottomOffset: CGFloat = 4.0
    private static let temperatureTitleFontSize: CGFloat = 11.0
    private static let smallTemperatureFontSize: CGFloat = 15.0
    private static let largeTemperatureFontSize: CGFloat = 17.0
    private static let minimumTemperatureFontSize: CGFloat = 7.0
    /// Fine enough that a row filling the width never leaves a visible gap at its end.
    private static let temperatureScaleStep: CGFloat = 0.05
    /// A slight inset, so a row filling the width sits just inside the speed bar's ends.
    private static let temperatureRowInset: CGFloat = 1.0
    private static let minimumScaleFactor: CGFloat = 0.5
    private static let barHeight: CGFloat = 4.0
    // Each size shows the first fans in order, as many as fit with the temperatures and footer still in view.
    private static let smallFanLimit: Int = 1
    private static let mediumFanLimit: Int = 2
    private static let largeFanLimit: Int = 4
    private static let extraLargeFanLimit: Int = 6
    /// Two columns keep each fan wide enough for its limits line.
    private static let extraLargeFanColumnCount: Int = 2
    private static let extraLargeColumnSpacing: CGFloat = 32.0
    
    let entry: ReadingsEntry
    
    @Environment(\.widgetFamily) private var widgetFamily: WidgetFamily
    
    private var valueStyle: HierarchicalShapeStyle {
        return entry.isStale ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary
    }
    
    private var unit: FannySettings.TemperatureUnit {
        return entry.settings.temperatureUnit
    }
    
    /// Hidden temperatures disappear entirely, like in the menu.
    private var temperatureItems: [TemperatureItem] {
        var items: [TemperatureItem] = []
        
        if entry.settings.showsCPUTemperature {
            items.append(TemperatureItem(id: "cpu", title: ReadingFormatter.cpuTitle, symbol: .cpu, reading: entry.snapshot?.cpuTemperature))
        }
        
        if entry.settings.showsGPUTemperature {
            items.append(TemperatureItem(id: "gpu", title: ReadingFormatter.gpuTitle, symbol: .thermometerMedium, reading: entry.snapshot?.gpuTemperature))
        }
        
        return items
    }
    
    /// The fans this size has room for, from Fan 1 on, so every size starts with the same fan.
    private var shownFans: [FanReading] {
        let limit: Int
        
        switch widgetFamily {
        case .systemMedium:
            limit = ReadingsView.mediumFanLimit
        case .systemLarge:
            limit = ReadingsView.largeFanLimit
        case .systemExtraLarge:
            limit = ReadingsView.extraLargeFanLimit
        default:
            limit = ReadingsView.smallFanLimit
        }
        
        return Array((entry.snapshot?.fans ?? []).prefix(limit))
    }
    
    /// `nil` when the snapshot has fans to show.
    private var fanMessage: String? {
        let message: String?
        
        switch entry.snapshot?.fanStatus {
        case .fans:
            message = nil
        case .noFans:
            message = String(localized: "No Fans", comment: "Widget: shown in place of the fan speeds on a Mac without fans, such as a MacBook Air.")
        case .unavailable:
            message = String(localized: "Readings Unavailable", comment: "Widget: shown in place of the fan speeds when they could not be read.")
        case nil:
            message = ReadingFormatter.missingText
        }
        
        return message
    }
    
    var body: some View {
        content
            .padding(ReadingsView.contentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(.fill.tertiary, for: .widget)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: "Fanny"))
            .accessibilityValue(Text(accessibilityValue()))
            .onAppear {
                // The gallery and placeholder renders are not the user using the widget.
                guard entry.isPreview == false else { return }
                UserManager.shared.userUsedWidgetExtension()
            }
    }
    
    // MARK: - Layouts
    @ViewBuilder
    private var content: some View {
        switch widgetFamily {
        case .systemMedium:
            mediumLayout
        case .systemLarge:
            largeLayout
        case .systemExtraLarge:
            extraLargeLayout
        default:
            smallLayout
        }
    }
    
    /// Fan 1 leads, with the temperatures in one smaller row under it.
    private var smallLayout: some View {
        // No stack spacing, so the spacers alone decide the gaps and a two-line footer still leaves the fan its full size.
        return VStack(alignment: .leading, spacing: 0.0) {
            if fanMessage == nil, let fan: FanReading = shownFans.first {
                fanView(fan, fontSize: ReadingsView.smallFanFontSize, showsLimits: false)
            }
            else {
                fanMessageView
            }
            
            // Equal room above and below, so the temperatures sit midway between the speed bar and the footer.
            Spacer(minLength: ReadingsView.spacing)
            temperaturesView(valueFontSize: ReadingsView.smallTemperatureFontSize, showsSymbols: false, maximumValueFontSize: ReadingsView.smallFanFontSize)
            Spacer(minLength: ReadingsView.spacing)
            footer
        }
    }
    
    private var mediumLayout: some View {
        return VStack(alignment: .leading, spacing: 0.0) {
            fansView(fontSize: ReadingsView.mediumFanFontSize, isHorizontal: true, showsLimits: false)
            Spacer(minLength: ReadingsView.spacing)
            
            // Columns like the fans above, so the temperatures span only Fan 1's speed bar, as on the small widget.
            HStack(alignment: .center, spacing: ReadingsView.temperatureSpacing) {
                temperaturesView(valueFontSize: ReadingsView.smallTemperatureFontSize, showsSymbols: true, maximumValueFontSize: ReadingsView.mediumFanFontSize)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: 0.0)
            }
            
            Spacer(minLength: ReadingsView.spacing)
            footer
        }
    }
    
    private var largeLayout: some View {
        return VStack(alignment: .leading, spacing: ReadingsView.spacing * 1.5) {
            fansView(fontSize: ReadingsView.largeFanFontSize, isHorizontal: false, showsLimits: true)
            Spacer(minLength: 0.0)
            
            if temperatureItems.isEmpty == false {
                Divider()
                temperaturesView(valueFontSize: ReadingsView.largeTemperatureFontSize, showsSymbols: true, maximumValueFontSize: nil)
            }
            
            footer
        }
    }
    
    /// The fans with their limits in rows of two, then the temperatures, like the large widget.
    private var extraLargeLayout: some View {
        return VStack(alignment: .leading, spacing: ReadingsView.spacing * 1.5) {
            fanGridView
            Spacer(minLength: 0.0)
            
            if temperatureItems.isEmpty == false {
                Divider()
                temperaturesView(valueFontSize: ReadingsView.largeTemperatureFontSize, showsSymbols: true, maximumValueFontSize: nil)
            }
            
            footer
        }
    }
    
    // MARK: - Subviews
    /// The temperatures in one row, each title beside its value, smaller than the fan speeds.
    /// - Parameter maximumValueFontSize: When set, the row grows until it spans the speed bars above it, with its first and last temperatures just inside the two edges, like the speed, and its values never outgrow this size. `nil` keeps the row at its own size.
    /// - Note: When the row is too wide, the values shrink first, down to the size of their titles, then both shrink together, so a value never reads smaller than its title.
    @ViewBuilder
    private func temperaturesView(valueFontSize: CGFloat, showsSymbols: Bool, maximumValueFontSize: CGFloat?) -> some View {
        if temperatureItems.isEmpty == false {
            let fillsWidth: Bool = maximumValueFontSize != nil
            
            ViewThatFits(in: .horizontal) {
                ForEach(Array(ReadingsView.temperatureFontSizes(valueFontSize: valueFontSize, maximumValueFontSize: maximumValueFontSize).enumerated()), id: \.offset) { _, sizes in
                    temperaturesRow(sizes: sizes, showsSymbols: showsSymbols, fillsWidth: fillsWidth)
                }
            }
            .padding(.horizontal, fillsWidth ? ReadingsView.temperatureRowInset : 0.0)
        }
    }
    
    /// One row of temperatures at the given sizes, each title beside its value.
    /// - Parameter fillsWidth: Spreads the temperatures out to the row's edges instead of keeping them a fixed distance apart.
    private func temperaturesRow(sizes: TemperatureFontSizes, showsSymbols: Bool, fillsWidth: Bool) -> some View {
        var items: [TemperatureItem] = temperatureItems
        
        // A lone temperature sizes itself as if the other were beside it, so it keeps the left half instead of growing to the full width.
        if fillsWidth, let item: TemperatureItem = items.first, items.count == 1 {
            items.append(TemperatureItem(id: "\(item.id)-placeholder", title: item.title, symbol: item.symbol, reading: item.reading, isPlaceholder: true))
        }
        
        return TemperatureRowLayout(spacing: ReadingsView.temperatureSpacing, fillsWidth: fillsWidth) {
            ForEach(items) { item in
                // Centered, so the small title sits level with the middle of its larger value.
                HStack(alignment: .center, spacing: ReadingsView.smallSpacing * 2.0) {
                    HStack(alignment: .center, spacing: ReadingsView.symbolLabelSpacing) {
                        if showsSymbols {
                            Image(systemSymbol: item.symbol)
                                .frame(width: ReadingsView.temperatureSymbolWidth(fontSize: sizes.title))
                        }
                        
                        Text(item.title)
                            .capCentered(fontSize: sizes.title, weight: .medium)
                    }
                    .font(.system(size: sizes.title, weight: .medium))
                    .foregroundStyle(.secondary)
                    
                    Text(ReadingFormatter.temperatureText(item.reading, unit: unit, style: .compact))
                        .font(.system(size: sizes.value, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(valueStyle)
                }
                .opacity(item.isPlaceholder ? 0.0 : 1.0)
                .accessibilityHidden(item.isPlaceholder)
            }
        }
        .lineLimit(1)
    }
    
    /// The widest temperature symbol at this size, so each symbol centers in the same slot and its title sits as far from it as the other's, like the floating window.
    private static func temperatureSymbolWidth(fontSize: CGFloat) -> CGFloat {
        let configuration: NSImage.SymbolConfiguration = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .medium)
        let symbols: [SFSymbol] = [SFSymbol.cpu,
                                   SFSymbol.thermometerMedium,]
        let widths: [CGFloat] = symbols.compactMap({ NSImage(systemSymbol: $0, accessibilityDescription: nil).withSymbolConfiguration(configuration)?.size.width })
        return ceil(widths.max() ?? fontSize)
    }
    
    /// Any larger sizes first, scaling the titles and values together, then the full size, then each smaller value down to the title's size, then both together.
    private static func temperatureFontSizes(valueFontSize: CGFloat, maximumValueFontSize: CGFloat?) -> [TemperatureFontSizes] {
        var sizes: [TemperatureFontSizes] = []
        
        if let maximumValueFontSize: CGFloat = maximumValueFontSize {
            var scale: CGFloat = maximumValueFontSize / valueFontSize
            
            while scale > 1.0 {
                sizes.append(TemperatureFontSizes(title: temperatureTitleFontSize * scale, value: valueFontSize * scale))
                scale = scale - temperatureScaleStep
            }
        }
        
        var value: CGFloat = valueFontSize
        
        while value > temperatureTitleFontSize {
            sizes.append(TemperatureFontSizes(title: temperatureTitleFontSize, value: value))
            value = value - 1.0
        }
        
        var shared: CGFloat = temperatureTitleFontSize
        
        while shared >= minimumTemperatureFontSize {
            sizes.append(TemperatureFontSizes(title: shared, value: shared))
            shared = shared - 1.0
        }
        
        return sizes
    }
    
    /// The fan symbol beside the message that replaces the fans, such as No Fans.
    private var fanMessageView: some View {
        let fontSize: CGFloat = NSFont.preferredFont(forTextStyle: NSFont.TextStyle.title3).pointSize
        let message: String = fanMessage ?? ReadingFormatter.missingText
        
        // Centered on the capitals, so the message sits level with the middle of the fan symbol, like the fan names.
        return HStack(alignment: .center, spacing: ReadingsView.symbolLabelSpacing) {
            // Slashed, since every message here means there are no fan speeds to show.
            Image(systemSymbol: .fanSlash)
                .foregroundStyle(.secondary)
            
            if message == ReadingFormatter.missingText {
                // Dashes sit below the middle of the capitals, so they center on their own marks instead.
                Text(message)
                    .inkCentered(message, fontSize: fontSize, weight: .semibold)
                    .foregroundStyle(valueStyle)
            }
            else {
                Text(message)
                    .capCentered(fontSize: fontSize, weight: .semibold)
                    .foregroundStyle(valueStyle)
            }
        }
        .font(.title3.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(ReadingsView.minimumScaleFactor)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func fansView(fontSize: CGFloat, isHorizontal: Bool, showsLimits: Bool) -> some View {
        if fanMessage != nil {
            fanMessageView
        }
        else {
            let layout: AnyLayout = isHorizontal ? AnyLayout(HStackLayout(alignment: .top, spacing: ReadingsView.temperatureSpacing)) : AnyLayout(VStackLayout(alignment: .leading, spacing: ReadingsView.spacing * 1.5))
            
            layout {
                ForEach(shownFans) { fan in
                    fanView(fan, fontSize: fontSize, showsLimits: showsLimits)
                }
                
                // A Mac with one fan keeps the empty second column, so Fan 1 has the same width as beside Fan 2.
                if isHorizontal, shownFans.count == 1 {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: 0.0)
                }
            }
        }
    }
    
    /// The fans with their limits, in rows of equal columns so a lone fan in the last row keeps the same width.
    @ViewBuilder
    private var fanGridView: some View {
        if fanMessage != nil {
            fanMessageView
        }
        else {
            let column: GridItem = GridItem(.flexible(), spacing: ReadingsView.extraLargeColumnSpacing, alignment: .topLeading)
            let columns: [GridItem] = Array(repeating: column, count: ReadingsView.extraLargeFanColumnCount)
            
            LazyVGrid(columns: columns, alignment: .leading, spacing: ReadingsView.spacing * 1.5) {
                ForEach(shownFans) { fan in
                    fanView(fan, fontSize: ReadingsView.largeFanFontSize, showsLimits: true)
                }
            }
        }
    }
    
    /// The fan's name over its speed in large digits, then its speed bar.
    private func fanView(_ fan: FanReading, fontSize: CGFloat, showsLimits: Bool) -> some View {
        return VStack(alignment: .leading, spacing: ReadingsView.smallSpacing * 2.0) {
            HStack(alignment: .center, spacing: ReadingsView.symbolLabelSpacing) {
                Image(systemSymbol: .fan)
                
                Text(ReadingFormatter.fanName(id: fan.id, settings: entry.settings))
                    .capCentered(fontSize: ReadingsView.temperatureTitleFontSize, weight: .medium)
            }
            .font(.system(size: ReadingsView.temperatureTitleFontSize, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            
            HStack(alignment: .firstTextBaseline, spacing: ReadingsView.smallSpacing * 2.0) {
                Text(ReadingFormatter.compactFanSpeedText(fan))
                    .font(.system(size: fontSize, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(valueStyle)
                
                // A stopped fan reads Off, which needs no unit.
                if fan.isStopped == false {
                    Text(ReadingsView.rpmText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(ReadingsView.minimumScaleFactor)
            
            if let fraction: Double = fan.speedFraction {
                speedBar(fraction: fraction)
            }
            
            if showsLimits, let limitsText: ReadingFormatter.SpokenText = ReadingFormatter.fanLimitsText(fan) {
                Text(limitsText.text)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(ReadingsView.minimumScaleFactor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// A thin bar from the fan's minimum to its maximum speed.
    private func speedBar(fraction: Double) -> some View {
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                
                Capsule()
                    .fill(valueStyle)
                    .frame(width: proxy.size.width * CGFloat(fraction))
            }
        }
        .frame(height: ReadingsView.barHeight)
        .accessibilityHidden(true)
    }
    
    /// The snapshot to count the age from. Once it is stale, such as after Fanny quit, or the fans could not be read, the footer asks for a click instead.
    private var freshSnapshot: ReadingsSnapshot? {
        guard
            let snapshot: ReadingsSnapshot = entry.snapshot,
            entry.isStale == false,
            snapshot.fanStatus != ReadingsSnapshot.FanStatus.unavailable
        else { return nil }
        return snapshot
    }
    
    /// True when the last read is an hour old or more, so the footer says so above Click to Refresh.
    private var isOverAnHourOld: Bool {
        guard let snapshot: ReadingsSnapshot = entry.snapshot else { return false }
        return entry.date.timeIntervalSince(snapshot.capturedDate) >= ReadingsSnapshot.staleTimeInterval
    }
    
    @ViewBuilder
    private var footer: some View {
        Group {
            if let snapshot: ReadingsSnapshot = freshSnapshot {
                // Plain text redrawn by a timeline entry each minute, because a live date text fills the widget's width and ignores the trailing alignment.
                // Hidden rather than removed until the age shows, so the layout never jumps when it appears.
                Text("Updated \(ReadingsView.ageText(from: snapshot.capturedDate, to: entry.date))", comment: "Widget footer: how long ago the readings were taken. The argument reads like 2 minutes ago or 59 minutes ago.")
                    .opacity(ReadingsTimeline.showsAge(of: snapshot, at: entry.date) ? 1.0 : 0.0)
            }
            else {
                VStack(alignment: .trailing, spacing: ReadingsView.smallSpacing) {
                    if isOverAnHourOld {
                        Text(ReadingsView.overAnHourAgoText)
                    }
                    
                    // Clicking the widget opens Fanny, whose first read reloads the widget.
                    HStack(alignment: .center, spacing: ReadingsView.symbolLabelSpacing) {
                        Image(systemSymbol: .arrowClockwise)
                        
                        Text(ReadingsView.clickToRefreshText)
                            .capCentered(fontSize: ReadingsView.footerFontSize, weight: .light)
                    }
                }
            }
        }
        .font(.system(size: ReadingsView.footerFontSize, weight: .light))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(ReadingsView.minimumScaleFactor)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .offset(y: ReadingsView.footerBottomOffset)
    }
    
    // MARK: - Content
    private static var rpmText: String {
        return String(localized: "RPM", comment: "Widget: small unit beside a fan speed, revolutions per minute.")
    }
    
    /// The age in whole minutes, such as 2 minutes ago, in the system's language.
    private static func ageText(from capturedDate: Date, to date: Date) -> String {
        let formatter: RelativeDateTimeFormatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        let minutes: TimeInterval = (date.timeIntervalSince(capturedDate) / 60.0).rounded(.down)
        return formatter.localizedString(fromTimeInterval: -minutes * 60.0)
    }
    
    private static var clickToRefreshText: String {
        return String(localized: "Click to Refresh", comment: "Widget footer after a refresh symbol: the readings are old or missing, and clicking the widget opens Fanny to read them again.")
    }
    
    private static var overAnHourAgoText: String {
        return String(localized: "Updated over an hour ago", comment: "Widget footer above Click to Refresh: the last readings were taken an hour or more ago.")
    }
    
    private static var spokenOutOfDateText: String {
        return String(localized: "Readings are out of date. Click to refresh.", comment: "Spoken by VoiceOver on the widget when the readings are old or missing.")
    }
    
    private func accessibilityValue() -> String {
        var parts: [String] = []
        
        // Fans first, in the order the widget shows them.
        if let fanMessage: String = fanMessage {
            parts.append(entry.snapshot == nil ? ReadingFormatter.spokenFanSpeedText(nil) : fanMessage)
        }
        else {
            // The large and extra large widgets show each fan's limits, so VoiceOver reads them too.
            let showsLimits: Bool = widgetFamily == WidgetFamily.systemLarge || widgetFamily == WidgetFamily.systemExtraLarge
            parts.append(contentsOf: shownFans.map({ fan in
                let speedText: String = "\(ReadingFormatter.fanName(id: fan.id, settings: entry.settings)), \(ReadingFormatter.spokenFanSpeedText(fan))"
                guard showsLimits, let limitsText: ReadingFormatter.SpokenText = ReadingFormatter.fanLimitsText(fan) else { return speedText }
                return "\(speedText), \(limitsText.spokenText)"
            }))
        }
        
        parts.append(contentsOf: temperatureItems.map({ "\($0.title), \(ReadingFormatter.spokenTemperatureText($0.reading, unit: unit, style: .compact))" }))
        
        if let snapshot: ReadingsSnapshot = freshSnapshot {
            // A clock time, because a spoken age would go stale between timeline entries while the footer keeps counting.
            let timeText: String = snapshot.capturedDate.formatted(date: .omitted, time: .shortened)
            parts.append(String(localized: "Updated at \(timeText)", comment: "Spoken by VoiceOver on the widget: the time the readings were taken, such as 3:45 PM."))
        }
        else {
            if isOverAnHourOld {
                parts.append(ReadingsView.overAnHourAgoText)
            }
            
            parts.append(ReadingsView.spokenOutOfDateText)
        }
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - TemperatureRowLayout
/// Lays the temperatures out in a row at their own sizes, and when filling, spreads them so the first and last sit at the two edges.
/// - Note: It reports its full natural width whenever that is wider than offered, so `ViewThatFits` moves on to a smaller size instead of squeezing the text.
private struct TemperatureRowLayout: Layout {
    
    let spacing: CGFloat
    let fillsWidth: Bool
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes: [CGSize] = subviews.map({ $0.sizeThatFits(ProposedViewSize.unspecified) })
        let naturalWidth: CGFloat = sizes.reduce(0.0, { $0 + $1.width }) + spacing * CGFloat(max(sizes.count - 1, 0))
        let height: CGFloat = sizes.map({ $0.height }).max() ?? 0.0
        let width: CGFloat
        
        if fillsWidth, let proposedWidth: CGFloat = proposal.width, proposedWidth.isFinite, proposedWidth > naturalWidth {
            width = proposedWidth
        }
        else {
            width = naturalWidth
        }
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes: [CGSize] = subviews.map({ $0.sizeThatFits(ProposedViewSize.unspecified) })
        let itemsWidth: CGFloat = sizes.reduce(0.0, { $0 + $1.width })
        var gap: CGFloat = spacing
        
        if fillsWidth, sizes.count > 1 {
            gap = max(spacing, (bounds.width - itemsWidth) / CGFloat(sizes.count - 1))
        }
        
        var x: CGFloat = bounds.minX
        
        for (index, subview) in subviews.enumerated() {
            // Unspecified, so each temperature takes its ideal size, the one it was measured at, and rounding never truncates it.
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: UnitPoint.leading, proposal: ProposedViewSize.unspecified)
            x = x + sizes[index].width + gap
        }
    }
}

// MARK: - Text
private extension Text {
    
    /// Centers the text on its capital letters instead of its whole line, so it sits level with the middle of a symbol beside it.
    /// - Note: Text shrunk to fit keeps its capitals centered, since the cap height scales with the drawn ascent.
    func capCentered(fontSize: CGFloat, weight: NSFont.Weight) -> some View {
        let font: NSFont = NSFont.systemFont(ofSize: fontSize, weight: weight)
        
        return alignmentGuide(VerticalAlignment.center) { dimensions in
            let baseline: CGFloat = dimensions[VerticalAlignment.firstTextBaseline]
            let scale: CGFloat = font.ascender > 0.0 ? min(1.0, baseline / font.ascender) : 1.0
            return baseline - font.capHeight * scale / 2.0
        }
    }
    
    /// Centers the text on the marks it draws, for text without capitals, such as dashes.
    func inkCentered(_ string: String, fontSize: CGFloat, weight: NSFont.Weight) -> some View {
        let font: NSFont = NSFont.systemFont(ofSize: fontSize, weight: weight)
        let inkBounds: CGRect = (string as NSString).boundingRect(with: CGSize.zero, options: [NSString.DrawingOptions.usesDeviceMetrics], attributes: [NSAttributedString.Key.font: font])
        
        return alignmentGuide(VerticalAlignment.center) { dimensions in
            return dimensions[VerticalAlignment.firstTextBaseline] - inkBounds.midY
        }
    }
}
