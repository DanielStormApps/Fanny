//
//  AboutSettingsViewController.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa
import PureLayout
import SFSafeSymbols

/// The About pane: version, source code, support links, and Positive.
final class AboutSettingsViewController: ViewController {
    
    private let settingsScrollView: SettingsScrollView = SettingsScrollView()
    private let gitHubButton: NSButton = NSButton(title: AboutSettingsViewController.gitHubButtonTitle(starCount: SavedStarCount.load()?.count), target: nil, action: nil)
    private let requestFeatureButton: NSButton = NSButton(title: String(localized: "Request", comment: "Settings button that opens a new GitHub issue to request a feature (keep GitHub)."), target: nil, action: nil)
    private let reportProblemButton: NSButton = NSButton(title: String(localized: "Report", comment: "Settings button that opens a new GitHub issue to report a problem (keep GitHub)."), target: nil, action: nil)
    private let privacyButton: NSButton = NSButton(title: String(localized: "View", comment: "Settings button that opens the privacy policy."), target: nil, action: nil)
    private let positiveButton: NSButton = NSButton(title: String(localized: "Get Positive (Free)", comment: "Positive install prompt: get button (keep the app name)"), target: nil, action: nil)
    private let developerMenuButton: HoverRevealButton = HoverRevealButton()
    
    private static let developerMenuButtonSize: CGFloat = 16.0
    private static let developerMenuButtonInset: CGFloat = 12.0
    
    // MARK: - View Cycle
    override func loadView() {
        let containerView: NSView = NSView()
        containerView.addSubview(settingsScrollView)
        settingsScrollView.autoPinEdgesToSuperviewEdges()
        view = containerView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        analytics(title: "about")
        setupHeader()
        setupRows()
        setupDeveloperMenuButton()
        loadStarCount()
    }
    
    // MARK: - Setup
    private func setupHeader() {
        let iconImageView: NSImageView = NSImageView(image: NSApplication.shared.applicationIconImage)
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.hideFromAccessibility()
        iconImageView.autoSetDimensions(to: CGSize(width: 84.0, height: 84.0))
        
        let nameLabel: NSTextField = NSTextField(labelWithString: "Fanny")
        nameLabel.font = NSFont.systemFont(ofSize: NSFont.preferredFont(forTextStyle: .title1).pointSize, weight: .semibold)
        
        let versionLabel: NSTextField = NSTextField(labelWithString: String(localized: "Version \(Bundle.version)", comment: "Settings About: app version. The argument is the version number."))
        versionLabel.font = NSFont.preferredFont(forTextStyle: .callout)
        versionLabel.textColor = NSColor.secondaryLabelColor
        
        let headerStackView: NSStackView = NSStackView(views: [iconImageView, nameLabel, versionLabel])
        headerStackView.orientation = .vertical
        headerStackView.alignment = .centerX
        headerStackView.spacing = 6.0
        // The icon art carries its own transparent margin, so no extra space is needed above the name.
        headerStackView.setCustomSpacing(0.0, after: iconImageView)
        // The space taken from between the name and version goes above the icon, so the icon and name move down while the version stays put.
        headerStackView.setCustomSpacing(1.0, after: nameLabel)
        
        let headerView: NSView = NSView()
        headerView.addSubview(headerStackView)
        headerStackView.autoPinEdge(toSuperviewEdge: .top, withInset: 5.0)
        headerStackView.autoPinEdge(toSuperviewEdge: .bottom)
        headerStackView.autoAlignAxis(toSuperviewAxis: .vertical)
        
        let headerSectionView: SettingsHeaderContainer = SettingsHeaderContainer(contentView: headerView)
        settingsScrollView.addGroup(headerSectionView)
    }
    
    private func setupRows() {
        updateGitHubButton(starCount: SavedStarCount.load()?.count)
        gitHubButton.target = self
        gitHubButton.action = #selector(openGitHub)
        requestFeatureButton.target = self
        requestFeatureButton.action = #selector(requestFeature)
        reportProblemButton.target = self
        reportProblemButton.action = #selector(reportProblem)
        privacyButton.target = self
        privacyButton.action = #selector(openPrivacyPolicy)
        positiveButton.target = self
        positiveButton.action = #selector(downloadPositive)
        
        let group: SettingsGroupView = SettingsGroupView()
        group.addRow(SettingsRowView(title: String(localized: "Source Code", comment: "Settings row title for the Fanny source code."), subtitle: String(localized: "Fanny is free and open source.", comment: "Settings subtitle under Source Code (keep Fanny)."), control: gitHubButton))
        group.addRow(SettingsRowView(title: String(localized: "Request a Feature", comment: "Settings row title: suggest a new feature on GitHub."), control: requestFeatureButton))
        group.addRow(SettingsRowView(title: String(localized: "Report a Problem", comment: "Settings row title: report a bug on GitHub."), control: reportProblemButton))
        group.addRow(SettingsRowView(title: String(localized: "Privacy Policy", comment: "Settings row title for the privacy policy."), control: privacyButton))
        settingsScrollView.addGroup(group)
        
        let positiveGroup: SettingsGroupView = SettingsGroupView()
        positiveGroup.addRow(SettingsRowView(title: String(localized: "Positive", comment: "Settings row title: the name of the developer's other app (brand name, keep Positive)."), subtitle: String(localized: "Help keep Fanny free for everyone by downloading my other app Positive.", comment: "Settings subtitle asking the user to download Positive, the developer's other app (keep Fanny and Positive)."), icon: NSImage(named: "positive-icon"), control: positiveButton))
        settingsScrollView.addGroup(positiveGroup)
    }
    
    /// Small and faint in the bottom right corner, so it stays out of the way until someone looks for it.
    private func setupDeveloperMenuButton() {
        developerMenuButton.image = NSImage(systemSymbol: .wrenchAndScrewdriver, accessibilityDescription: DeveloperMenuWindowController.windowTitle)
        developerMenuButton.toolTip = DeveloperMenuWindowController.windowTitle
        developerMenuButton.target = self
        developerMenuButton.action = #selector(openDeveloperMenu)
        view.addSubview(developerMenuButton)
        developerMenuButton.autoSetDimensions(to: CGSize(width: AboutSettingsViewController.developerMenuButtonSize, height: AboutSettingsViewController.developerMenuButtonSize))
        developerMenuButton.autoPinEdge(toSuperviewEdge: .trailing, withInset: AboutSettingsViewController.developerMenuButtonInset)
        developerMenuButton.autoPinEdge(toSuperviewEdge: .bottom, withInset: AboutSettingsViewController.developerMenuButtonInset)
    }
    
    // MARK: - Actions
    @objc private func openDeveloperMenu() {
        trackAction("about_DeveloperMenu")
        DeveloperMenuWindowController.shared.show()
    }
    
    @objc private func openGitHub() {
        trackAction("about_GitHub")
        open(path: ConfigManager.shared.config.app?.gitHubPath, name: "GitHub")
    }
    
    @objc private func requestFeature() {
        trackAction("about_RequestFeature")
        openIssue(kind: .featureRequest)
    }
    
    @objc private func reportProblem() {
        trackAction("about_ReportProblem")
        openIssue(kind: .problem)
    }
    
    /// Opens the issue form with its label and this Mac's details filled in, so requests and problems arrive sorted and ready to look into.
    private func openIssue(kind: GitHubIssue.Kind) {
        guard
            let gitHubPath: String = ConfigManager.shared.config.app?.gitHubPath,
            let url: URL = GitHubIssue.url(kind: kind, gitHubPath: gitHubPath, fields: GitHubIssue.currentFields())
        else {
            Log.warn("🎛️ openIssue -> missing GitHub path")
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    @objc private func openPrivacyPolicy() {
        trackAction("about_PrivacyPolicy")
        open(path: ConfigManager.shared.config.app?.privacyPolicyPath, name: "privacy policy")
    }
    
    @objc private func downloadPositive() {
        trackAction("about_DownloadPositive")
        PositiveApp.openAppStore()
    }
    
    private func open(path: String?, name: String) {
        guard
            let path: String = path,
            let url: URL = URL(string: path)
        else {
            Log.warn("🎛️ open -> missing \(name) path")
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Stars
    /// Set on the first try, so a failed fetch waits for the next launch instead of repeating each time About opens.
    private static var didRequestStarCount: Bool = false
    /// Stars change slowly, so one fetch a day keeps the count current without spending GitHub's hourly request limit.
    private static let starCountRefreshTimeInterval: TimeInterval = 24.0 * 60.0 * 60.0
    
    /// The last star count GitHub returned, kept so the button still shows it offline, while GitHub is down, or after a rate limit.
    private struct SavedStarCount: Codable {
        let count: Int
        let date: Date
        
        static func load() -> SavedStarCount? {
            guard let data: Data = Storage.data(forKey: .gitHubStarCount) else { return nil }
            return try? JSONDecoder().decode(SavedStarCount.self, from: data)
        }
        
        func save() {
            guard let data: Data = try? JSONEncoder().encode(self) else { return }
            Storage.save(data, forKey: .gitHubStarCount)
        }
    }
    
    private struct GitHubRepository: Decodable {
        let stargazersCount: Int
        
        private enum CodingKeys: String, CodingKey {
            case stargazersCount = "stargazers_count"
        }
    }
    
    /// Fetches the star count when the saved one is a day old or missing. A failed fetch keeps the saved count, and the button stays plain only before the first success.
    private func loadStarCount() {
        guard
            AboutSettingsViewController.didRequestStarCount == false,
            AboutSettingsViewController.isStarCountRefreshDue(savedDate: SavedStarCount.load()?.date, date: Date()),
            let repositoryPath: String = UpdateChecker.repositoryPath(fromGitHubPath: ConfigManager.shared.config.app?.gitHubPath),
            let url: URL = URL(string: "https://api.github.com/repos/\(repositoryPath)")
        else { return }
        
        AboutSettingsViewController.didRequestStarCount = true
        let request: URLRequest = URLRequest(url: url, httpBody: nil, httpHeaderFields: ["Accept": "application/vnd.github+json", "User-Agent": "Fanny/\(Bundle.version)"], httpMethod: URLRequest.httpMethod.GET)
        
        Task { @MainActor [weak self] in
            guard
                let result: (data: Data, response: URLResponse) = try? await URLSession.shared.data(for: request),
                (result.response as? HTTPURLResponse)?.statusCode == 200,
                let repository: GitHubRepository = try? JSONDecoder().decode(GitHubRepository.self, from: result.data)
            else {
                Log.warn("🎛️ loadStarCount -> failed, keeping the saved count")
                return
            }
            
            SavedStarCount(count: repository.stargazersCount, date: Date()).save()
            self?.updateGitHubButton(starCount: repository.stargazersCount)
        }
    }
    
    /// A clock that moved backward also refreshes, so a date in the future never blocks the fetch.
    static func isStarCountRefreshDue(savedDate: Date?, date: Date) -> Bool {
        guard let savedDate: Date = savedDate else { return true }
        let elapsedTimeInterval: TimeInterval = date.timeIntervalSince(savedDate)
        return elapsedTimeInterval < 0.0 || elapsedTimeInterval >= AboutSettingsViewController.starCountRefreshTimeInterval
    }
    
    /// VoiceOver hears the full count, such as "View on GitHub, 1,412 stars", instead of the star glyph and "1.4k".
    private func updateGitHubButton(starCount: Int?) {
        gitHubButton.title = AboutSettingsViewController.gitHubButtonTitle(starCount: starCount)
        
        if let starCount: Int = starCount {
            gitHubButton.setAccessibilityLabel(String(localized: "View on GitHub, \(starCount) stars", comment: "Spoken by VoiceOver for the Settings button that opens the Fanny source code on GitHub, with how many people starred the repository (keep GitHub). The argument is the full count."))
        }
        else {
            gitHubButton.setAccessibilityLabel(nil)
        }
    }
    
    /// Such as "View on GitHub · ★ 1.4k", or just "View on GitHub" until a count is first saved.
    private static func gitHubButtonTitle(starCount: Int?) -> String {
        let title: String
        
        if let starCount: Int = starCount {
            let countText: String = AboutSettingsViewController.starCountText(starCount)
            title = String(localized: "View on GitHub · ★ \(countText)", comment: "Settings button that opens the Fanny source code on GitHub, with how many people starred the repository, such as 128 or 1.4k (keep GitHub).")
        }
        else {
            title = String(localized: "View on GitHub", comment: "Settings button that opens the Fanny source code on GitHub (keep GitHub).")
        }
        
        return title
    }
    
    /// Shortened like GitHub's own star count: 999, 1.4k, 12.3k, 123k, then 1.2m, rounded to the nearest shown digit.
    /// - Note: Always a period and a lowercase k or m, as on GitHub in every language.
    static func starCountText(_ count: Int) -> String {
        let thousands: Double = AboutSettingsViewController.roundedShortValue(Double(count) / 1_000.0)
        let text: String
        
        if count < 1_000 {
            text = String(count)
        }
        // Rounding up to 1000k reads as 1m instead.
        else if thousands < 1_000.0 {
            text = AboutSettingsViewController.shortValueText(thousands) + "k"
        }
        else {
            text = AboutSettingsViewController.shortValueText(AboutSettingsViewController.roundedShortValue(Double(count) / 1_000_000.0)) + "m"
        }
        
        return text
    }
    
    /// One decimal below 100, so 1390 reads 1.4k and 123456 reads 123k.
    private static func roundedShortValue(_ value: Double) -> Double {
        return value < 100.0 ? (value * 10.0).rounded(.toNearestOrAwayFromZero) / 10.0 : value.rounded(.toNearestOrAwayFromZero)
    }
    
    /// Drops a trailing .0, so 1.0 reads 1.
    private static func shortValueText(_ value: Double) -> String {
        return value == value.rounded(.down) ? String(Int(value)) : String(format: "%.1f", value)
    }
    
    // MARK: - Analytics
    private func trackAction(_ title: String) {
        let event: PageViewEvent = PageViewEvent(title: title)
        Analytics.shared.track(event: event)
    }
}

/// A borderless symbol button that rests faint and quickly fades to full opacity under the pointer.
private final class HoverRevealButton: NSButton {
    
    private var trackingArea: NSTrackingArea?
    
    private static let restingAlpha: CGFloat = 0.25
    private static let fadeDuration: TimeInterval = 0.12
    
    // MARK: - Init
    init() {
        super.init(frame: CGRect.zero)
        isBordered = false
        imageScaling = .scaleProportionallyUpOrDown
        contentTintColor = NSColor.secondaryLabelColor
        alphaValue = HoverRevealButton.restingAlpha
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Tracking
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea: NSTrackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let newTrackingArea: NSTrackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(newTrackingArea)
        trackingArea = newTrackingArea
    }
    
    override func mouseEntered(with event: NSEvent) {
        fade(to: 1.0)
    }
    
    override func mouseExited(with event: NSEvent) {
        fade(to: HoverRevealButton.restingAlpha)
    }
    
    private func fade(to alpha: CGFloat) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = HoverRevealButton.fadeDuration
            self.animator().alphaValue = alpha
        }
    }
}

/// A plain, unframed container that lets a header share the group stack's width.
private final class SettingsHeaderContainer: NSView {
    
    init(contentView: NSView) {
        super.init(frame: CGRect.zero)
        addSubview(contentView)
        contentView.autoPinEdgesToSuperviewEdges()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
