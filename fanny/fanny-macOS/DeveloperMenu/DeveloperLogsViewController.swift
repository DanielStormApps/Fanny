//
//  DeveloperLogsViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/25/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout
import SFSafeSymbols

/// The Developer Menu's Logs pane: file stats, a share button, and the current log file in a scrollable viewer.
final class DeveloperLogsViewController: ViewController {
    
    /// Statistics about the log files on this Mac.
    private struct LogStats {
        let fileCount: Int
        let totalSize: Int64
        let currentFileSize: Int64
        let oldestDate: Date?
        let newestDate: Date?
        
        static let empty: LogStats = LogStats(fileCount: 0, totalSize: 0, currentFileSize: 0, oldestDate: nil, newestDate: nil)
        
        var fileCountText: String {
            return String(localized: "\(fileCount) Files", comment: "Developer Menu: how many log files are saved, such as 3 Files.")
        }
        
        var totalSizeText: String {
            return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }
        
        var currentFileSizeText: String {
            return ByteCountFormatter.string(fromByteCount: currentFileSize, countStyle: .file)
        }
        
        /// One date when every file is from the same day, otherwise the oldest and newest.
        var dateRangeText: String {
            guard
                let oldestDate: Date = oldestDate,
                let newestDate: Date = newestDate
            else { return ReadingFormatter.missingText }
            
            let oldestText: String = oldestDate.formatted(date: .numeric, time: .omitted)
            let newestText: String = newestDate.formatted(date: .numeric, time: .omitted)
            return oldestText == newestText ? oldestText : String(localized: "\(oldestText) to \(newestText)", comment: "Developer Menu: the dates the saved logs span, such as 11/20/2026 to 11/26/2026. The arguments are the oldest and newest dates.")
        }
    }
    
    private let headerView: NSView = NSView()
    private let fileCountView: StatItemView = StatItemView(title: String(localized: "Files", comment: "Developer Menu: label above how many log files are saved."))
    private let totalSizeView: StatItemView = StatItemView(title: String(localized: "Total", comment: "Developer Menu: label above how much space all log files take up."))
    private let currentSizeView: StatItemView = StatItemView(title: String(localized: "Current", comment: "Developer Menu: label above the size of the log file being written now."))
    private let dateRangeView: StatItemView = StatItemView(title: String(localized: "Range", comment: "Developer Menu: label above the dates the saved logs span."))
    private let finderButton: NSButton = NSButton()
    private let shareButton: NSButton = NSButton()
    private let textScrollView: NSScrollView = NSTextView.scrollableTextView()
    private var headerTopConstraint: NSLayoutConstraint?
    private var hasScrolledToBottom: Bool = false
    
    private static let headerHeight: CGFloat = 60.0
    private static let horizontalInset: CGFloat = 20.0
    private static let buttonSpacing: CGFloat = 8.0
    private static let textInset: CGSize = CGSize(width: 12.0, height: 12.0)
    private static let logFontSize: CGFloat = 11.0
    
    private var textView: NSTextView? {
        return textScrollView.documentView as? NSTextView
    }
    
    // MARK: - View Cycle
    override func loadView() {
        view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analytics(title: "developerLogs")
        setupHeader()
        setupTextView()
    }
    
    /// Reads the logs on every open, since the window stays alive after it closes and the logs keep growing.
    override func viewWillAppear() {
        super.viewWillAppear()
        reload()
        hasScrolledToBottom = false
        view.needsLayout = true
    }
    
    /// The window's content runs under the toolbar, so the header starts below it.
    override func viewDidLayout() {
        super.viewDidLayout()
        headerTopConstraint?.constant = view.safeAreaInsets.top
        
        guard hasScrolledToBottom == false, let textView: NSTextView = textView else { return }
        hasScrolledToBottom = true
        textView.scrollToEndOfDocument(nil)
    }
    
    // MARK: - Setup
    private func setupHeader() {
        view.addSubview(headerView)
        headerTopConstraint = headerView.autoPinEdge(toSuperviewEdge: .top)
        headerView.autoPinEdge(toSuperviewEdge: .leading)
        headerView.autoPinEdge(toSuperviewEdge: .trailing)
        headerView.autoSetDimension(.height, toSize: DeveloperLogsViewController.headerHeight)
        
        let statsStackView: NSStackView = NSStackView(views: [fileCountView, totalSizeView, currentSizeView, dateRangeView])
        statsStackView.orientation = .horizontal
        statsStackView.distribution = .fillEqually
        statsStackView.alignment = .centerY
        statsStackView.spacing = 8.0
        headerView.addSubview(statsStackView)
        statsStackView.autoPinEdge(toSuperviewEdge: .leading, withInset: DeveloperLogsViewController.horizontalInset)
        statsStackView.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        shareButton.bezelStyle = .push
        shareButton.image = NSImage(systemSymbol: .squareAndArrowUp, accessibilityDescription: nil)
        shareButton.imagePosition = .imageLeading
        shareButton.title = String(localized: "Share", comment: "Developer Menu: button that shares every log file as a zip.")
        shareButton.target = self
        shareButton.action = #selector(shareLogs)
        shareButton.toolTip = String(localized: "Share every log file as a zip", comment: "Developer Menu: tooltip of the Share button (keep zip).")
        shareButton.setContentHuggingPriority(NSLayoutConstraint.Priority.required, for: .horizontal)
        headerView.addSubview(shareButton)
        shareButton.autoPinEdge(toSuperviewEdge: .trailing, withInset: DeveloperLogsViewController.horizontalInset)
        shareButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        finderButton.bezelStyle = .push
        finderButton.image = NSImage(systemSymbol: .folder, accessibilityDescription: nil)
        finderButton.imagePosition = .imageLeading
        finderButton.title = String(localized: "View in Finder", comment: "Developer Menu: button that opens the log folder in Finder (keep Finder).")
        finderButton.target = self
        finderButton.action = #selector(viewInFinder)
        finderButton.toolTip = String(localized: "Open the folder the log files are saved in", comment: "Developer Menu: tooltip of the View in Finder button.")
        finderButton.setContentHuggingPriority(NSLayoutConstraint.Priority.required, for: .horizontal)
        headerView.addSubview(finderButton)
        finderButton.autoPinEdge(.trailing, to: .leading, of: shareButton, withOffset: -DeveloperLogsViewController.buttonSpacing)
        finderButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        statsStackView.autoPinEdge(.trailing, to: .leading, of: finderButton, withOffset: -DeveloperLogsViewController.horizontalInset)
        
        let separator: NSBox = NSBox()
        separator.boxType = .separator
        headerView.addSubview(separator)
        separator.autoPinEdgesToSuperviewEdges(with: NSEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), excludingEdge: .top)
    }
    
    private func setupTextView() {
        textScrollView.hasVerticalScroller = true
        textScrollView.drawsBackground = false
        textScrollView.borderType = .noBorder
        view.addSubview(textScrollView)
        textScrollView.autoPinEdge(.top, to: .bottom, of: headerView)
        textScrollView.autoPinEdgesToSuperviewEdges(with: NSEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), excludingEdge: .top)
        
        guard let textView: NSTextView = textView else { return }
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.monospacedSystemFont(ofSize: DeveloperLogsViewController.logFontSize, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.textContainerInset = DeveloperLogsViewController.textInset
        textView.setAccessibilityLabel(String(localized: "Current Log", comment: "Developer Menu: VoiceOver name of the text area that shows the current log file."))
    }
    
    // MARK: - Loading
    private func reload() {
        let logFiles: [URL] = DeveloperLogsViewController.logFiles()
        let stats: LogStats = DeveloperLogsViewController.stats(logFiles: logFiles)
        fileCountView.update(value: stats.fileCountText)
        totalSizeView.update(value: stats.totalSizeText)
        currentSizeView.update(value: stats.currentFileSizeText)
        dateRangeView.update(value: stats.dateRangeText)
        shareButton.isEnabled = logFiles.isEmpty == false
        textView?.string = DeveloperLogsViewController.currentLogText(logFiles: logFiles)
    }
    
    private static func logFiles() -> [URL] {
        return FileLogger.shared.logFileURLs()
    }
    
    private static func creationDate(of fileURL: URL) -> Date {
        return (try? fileURL.resourceValues(forKeys: [URLResourceKey.creationDateKey]).creationDate) ?? Date.distantPast
    }
    
    private static func stats(logFiles: [URL]) -> LogStats {
        guard logFiles.isEmpty == false else { return LogStats.empty }
        
        let sizes: [Int64] = logFiles.map({ Int64((try? $0.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).fileSize) ?? 0) })
        let dates: [Date] = logFiles.map({ creationDate(of: $0) }).filter({ $0 != Date.distantPast })
        return LogStats(fileCount: logFiles.count, totalSize: sizes.reduce(0, +), currentFileSize: sizes.first ?? 0, oldestDate: dates.min(), newestDate: dates.max())
    }
    
    private static func currentLogText(logFiles: [URL]) -> String {
        let text: String
        
        if let currentLogFile: URL = logFiles.first {
            text = (try? String(contentsOf: currentLogFile, encoding: String.Encoding.utf8)) ?? String(localized: "The current log file could not be read.", comment: "Developer Menu: shown in place of the log text when the file can't be opened.")
        }
        else {
            text = String(localized: "No log files yet.", comment: "Developer Menu: shown in place of the log text before any log is saved.")
        }
        
        return text
    }
    
    // MARK: - Actions
    /// Opens the log folder in a Finder window, creating it first so Finder never shows an error before the first log is written.
    @objc private func viewInFinder() {
        let logDirectoryURL: URL = LogArchiver.logDirectoryURL()
        try? FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
        Log.info("🛠️ viewInFinder -> path: \(logDirectoryURL.path)")
        NSWorkspace.shared.open(logDirectoryURL)
    }
    
    @objc private func shareLogs(_ sender: NSButton) {
        guard let archiveURL: URL = LogArchiver.createLogArchive() else {
            Log.error("🛠️ shareLogs -> failed to create the log archive")
            NSSound.beep()
            return
        }
        
        Log.info("🛠️ shareLogs -> showing share picker")
        let picker: NSSharingServicePicker = NSSharingServicePicker(items: [archiveURL])
        picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: NSRectEdge.minY)
    }
}

// MARK: - StatItemView
/// One stat in the header: a small title over its value.
private final class StatItemView: NSView {
    
    private let titleLabel: NSTextField = NSTextField(labelWithString: "")
    private let valueLabel: NSTextField = NSTextField(labelWithString: "")
    
    // MARK: - Init
    init(title: String) {
        super.init(frame: CGRect.zero)
        titleLabel.stringValue = title
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setup() {
        // One stop that reads the title with its value, such as "Files, 3", instead of the number alone.
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(titleLabel.stringValue)
        titleLabel.hideFromAccessibility()
        valueLabel.hideFromAccessibility()
        
        titleLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        titleLabel.textColor = NSColor.secondaryLabelColor
        titleLabel.alignment = .center
        addSubview(titleLabel)
        titleLabel.autoPinEdgesToSuperviewEdges(with: NSEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), excludingEdge: .bottom)
        
        valueLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        valueLabel.textColor = NSColor.labelColor
        valueLabel.alignment = .center
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.cell?.truncatesLastVisibleLine = true
        addSubview(valueLabel)
        valueLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 2.0)
        valueLabel.autoPinEdgesToSuperviewEdges(with: NSEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), excludingEdge: .top)
    }
    
    // MARK: - Update
    func update(value: String) {
        valueLabel.stringValue = value
        setAccessibilityLabel(String(localized: "\(titleLabel.stringValue), \(value)", comment: "Spoken by VoiceOver for a stat with its value, such as Files, 3. The first argument is the stat's name, the second its value."))
    }
}
