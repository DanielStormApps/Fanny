//
//  UpdateChecker.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

// MARK: - AvailableUpdate
/// A GitHub release that is newer than the running app.
struct AvailableUpdate: Codable, Equatable {
    let version: String
    let url: URL
    
    // MARK: - Storage
    /// - Returns: `nil` when no update was found, or the saved one cannot be read.
    static func load() -> AvailableUpdate? {
        guard let data: Data = Storage.data(forKey: .availableUpdate) else { return nil }
        return try? JSONDecoder().decode(AvailableUpdate.self, from: data)
    }
    
    static func remove() {
        Storage.removeObject(forKey: .availableUpdate)
    }
    
    func save() {
        guard let data: Data = try? JSONEncoder().encode(self) else { return }
        Storage.save(data, forKey: .availableUpdate)
    }
}

// MARK: - UpdateCheckerDelegate
/// Listeners told when a check starts or finishes, or the available update changes.
protocol UpdateCheckerDelegate: AnyObject {
    func updateCheckerDidUpdateStatus(_ checker: UpdateChecker)
}

// MARK: - UpdateChecker
/// Singleton that asks GitHub for the latest release and remembers a newer one for the menu and Settings.
/// - Note: Everything runs on the main thread. The request sends no identifiers, and only the tag and release link are read.
final class UpdateChecker {
    
    /// What one request to GitHub found.
    enum CheckResult: Equatable {
        case release(tagName: String, url: URL?, eTag: String?)
        case notModified
        /// A repository with no public release answers 404, so it reads as up to date.
        case noRelease
        case failed(reason: String)
    }
    
    /// The only fields read from GitHub's release.
    private struct LatestRelease: Decodable {
        let tagName: String
        let htmlURL: String?
        
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }
    
    let delegate: DelegateMulticast<UpdateCheckerDelegate> = DelegateMulticast<UpdateCheckerDelegate>()
    
    private(set) var availableUpdate: AvailableUpdate?
    private(set) var lastCheckDate: Date?
    private(set) var isChecking: Bool = false
    /// Set when a manual check fails, until the next check starts.
    private(set) var didFailManualCheck: Bool = false
    
    private var isStarted: Bool = false
    private var checksForUpdatesAutomatically: Bool = false
    private var isManualCheckPending: Bool = false
    private var checkTimer: Timer?
    /// Called once the check in flight finishes, for Shortcuts that wait on the result.
    private var checkCompletions: [() -> Void] = []
    
    /// Ephemeral and uncached, so the saved ETag is the only validator and a 304 always reaches the checker.
    private let session: URLSession = UpdateChecker.makeSession()
    
    private static let checkTimeInterval: TimeInterval = 12.0 * 60.0 * 60.0
    private static let checkToleranceRatio: Double = 0.1
    private static let automaticCheckTimeInterval: TimeInterval = 24.0 * 60.0 * 60.0
    private static let requestTimeoutInterval: TimeInterval = 30.0
    
    // MARK: - Init
    private init() {}
    static let shared: UpdateChecker = UpdateChecker()
    
    // MARK: - Start
    /// Loads the last result, checks if one is due, and looks again every 12 hours while running. Later calls do nothing.
    func start() {
        guard isStarted == false else { return }
        isStarted = true
        
        lastCheckDate = Storage.date(forKey: .lastUpdateCheckDate)
        availableUpdate = UpdateChecker.loadAvailableUpdate(currentVersion: Bundle.version)
        checksForUpdatesAutomatically = FannySettingsManager.shared.settings.checksForUpdatesAutomatically
        FannySettingsManager.shared.delegate.add(self)
        
        let timer: Timer = Timer(timeInterval: UpdateChecker.checkTimeInterval, repeats: true) { [weak self] _ in
            self?.checkIfNeeded()
        }
        timer.tolerance = UpdateChecker.checkTimeInterval * UpdateChecker.checkToleranceRatio
        RunLoop.main.add(timer, forMode: .common)
        checkTimer = timer
        
        Log.info("🔄 UpdateChecker start -> lastCheckDate: \(lastCheckDate?.description ?? "never"), availableUpdate: \(availableUpdate?.version ?? "none")")
        checkIfNeeded()
    }
    
    /// A saved update the running app already reached is dropped, so the menu stops offering it after an upgrade.
    private static func loadAvailableUpdate(currentVersion: String) -> AvailableUpdate? {
        guard let savedUpdate: AvailableUpdate = AvailableUpdate.load() else { return nil }
        guard isNewer(savedUpdate.version, than: currentVersion) else {
            AvailableUpdate.remove()
            return nil
        }
        
        return savedUpdate
    }
    
    // MARK: - Check
    /// Checks only when automatic checks are on and the last check was over a day ago.
    func checkIfNeeded() {
        let isEnabled: Bool = FannySettingsManager.shared.settings.checksForUpdatesAutomatically
        guard UpdateChecker.isAutomaticCheckDue(isEnabled: isEnabled, lastCheckDate: lastCheckDate, date: Date()) else {
            Log.debug("🔄 checkIfNeeded -> not due, enabled: \(isEnabled)")
            return
        }
        
        check(isManual: false)
    }
    
    /// Always checks, and reports a failure in Settings.
    func checkNow() {
        check(isManual: true)
    }
    
    /// Checks like Check Now, and returns once the result is in `statusText` and `availableUpdate`.
    @MainActor
    func checkNow() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            checkCompletions.append({ continuation.resume() })
            checkNow()
        }
    }
    
    /// A manual check asked for while an automatic one is in flight takes over that check's result.
    private func check(isManual: Bool) {
        if isManual {
            isManualCheckPending = true
        }
        
        guard isChecking == false else { return }
        
        guard
            let repositoryPath: String = UpdateChecker.repositoryPath(fromGitHubPath: ConfigManager.shared.config.app?.gitHubPath),
            let request: URLRequest = UpdateChecker.makeRequest(repositoryPath: repositoryPath, eTag: Storage.string(forKey: .updateCheckETag), appVersion: Bundle.version)
        else {
            handle(CheckResult.failed(reason: "missing GitHub path"))
            return
        }
        
        isChecking = true
        didFailManualCheck = false
        Log.info("🔄 check -> manual: \(isManual)")
        delegate.invoke({ $0.updateCheckerDidUpdateStatus(self) })
        
        UpdateChecker.performRequest(request, session: session) { [weak self] result in
            guard let strongSelf: UpdateChecker = self else { return }
            strongSelf.handle(result)
        }
    }
    
    private func handle(_ result: CheckResult) {
        let isManual: Bool = isManualCheckPending
        isManualCheckPending = false
        isChecking = false
        
        switch result {
        case .release(let tagName, let url, let eTag):
            Storage.save(eTag, forKey: .updateCheckETag)
            markChecked()
            let repositoryPath: String? = UpdateChecker.repositoryPath(fromGitHubPath: ConfigManager.shared.config.app?.gitHubPath)
            let update: AvailableUpdate? = repositoryPath.flatMap({ UpdateChecker.availableUpdate(tagName: tagName, releaseURL: url, currentVersion: Bundle.version, repositoryPath: $0) })
            setAvailableUpdate(update)
            Log.info("🔄 handle -> latest: \(tagName), availableUpdate: \(update?.version ?? "none")")
        case .notModified:
            markChecked()
            Log.info("🔄 handle -> not modified, availableUpdate: \(availableUpdate?.version ?? "none")")
        case .noRelease:
            Storage.removeObject(forKey: .updateCheckETag)
            markChecked()
            setAvailableUpdate(nil)
            Log.info("🔄 handle -> no public release")
        case .failed(let reason):
            didFailManualCheck = isManual
            Log.warn("🔄 handle -> failed, manual: \(isManual), reason: \(reason)")
        }
        
        delegate.invoke({ $0.updateCheckerDidUpdateStatus(self) })
        
        let completions: [() -> Void] = checkCompletions
        checkCompletions = []
        
        for completion in completions {
            completion()
        }
    }
    
    private func markChecked() {
        let date: Date = Date()
        lastCheckDate = date
        Storage.save(date, forKey: .lastUpdateCheckDate)
    }
    
    private func setAvailableUpdate(_ update: AvailableUpdate?) {
        availableUpdate = update
        
        if let update: AvailableUpdate = update {
            update.save()
        }
        else {
            AvailableUpdate.remove()
        }
    }
    
    // MARK: - Open
    /// Opens the release page, but only on the Fanny repository on github.com.
    func openAvailableUpdate() {
        guard
            let availableUpdate: AvailableUpdate = availableUpdate,
            let repositoryPath: String = UpdateChecker.repositoryPath(fromGitHubPath: ConfigManager.shared.config.app?.gitHubPath),
            UpdateChecker.isTrustedReleaseURL(availableUpdate.url, repositoryPath: repositoryPath)
        else {
            Log.warn("🔄 openAvailableUpdate -> no trusted release link")
            return
        }
        
        NSWorkspace.shared.open(availableUpdate.url)
    }
    
    // MARK: - Status
    var statusText: String {
        return UpdateChecker.statusText(isChecking: isChecking, didFailManualCheck: didFailManualCheck, availableUpdate: availableUpdate, lastCheckDate: lastCheckDate)
    }
    
    static func statusText(isChecking: Bool, didFailManualCheck: Bool, availableUpdate: AvailableUpdate?, lastCheckDate: Date?) -> String {
        let text: String
        
        if isChecking {
            text = String(localized: "Checking for Updates...", comment: "Settings subtitle while Fanny asks GitHub for a newer version.")
        }
        else if didFailManualCheck {
            text = String(localized: "Couldn't Check for Updates", comment: "Settings subtitle after a manual update check failed, for example with no internet connection.")
        }
        else if let availableUpdate: AvailableUpdate = availableUpdate {
            text = String(localized: "Fanny \(availableUpdate.version) is available.", comment: "Settings subtitle when a newer version exists. The argument is the version number (keep Fanny).")
        }
        else if let lastCheckDate: Date = lastCheckDate {
            let dateText: String = lastCheckDate.formatted(date: .abbreviated, time: .shortened)
            text = String(localized: "Fanny is up to date. Last checked \(dateText).", comment: "Settings subtitle when no newer version exists. The argument is the date and time of the last check (keep Fanny).")
        }
        else {
            text = String(localized: "Not checked yet.", comment: "Settings subtitle before Fanny has ever checked for updates.")
        }
        
        return text
    }
    
    // MARK: - Request
    private static func makeSession() -> URLSession {
        let configuration: URLSessionConfiguration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = UpdateChecker.requestTimeoutInterval
        return URLSession(configuration: configuration)
    }
    
    static func makeRequest(repositoryPath: String, eTag: String?, appVersion: String) -> URLRequest? {
        guard let url: URL = URL(string: "https://api.github.com/repos/\(repositoryPath)/releases/latest") else { return nil }
        
        var httpHeaderFields: [String: String] = ["Accept": "application/vnd.github+json", "User-Agent": "Fanny/\(appVersion)"]
        
        if let eTag: String = eTag, eTag.isEmpty == false {
            httpHeaderFields["If-None-Match"] = eTag
        }
        
        var request: URLRequest = URLRequest(url: url, httpBody: nil, httpHeaderFields: httpHeaderFields, httpMethod: URLRequest.httpMethod.GET)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = UpdateChecker.requestTimeoutInterval
        return request
    }
    
    /// Calls `completion` on the main thread.
    static func performRequest(_ request: URLRequest, session: URLSession, completion: @escaping (CheckResult) -> Void) {
        session.dataTask(with: request) { data, response, error in
            let result: CheckResult = UpdateChecker.checkResult(data: data, response: response, error: error)
            
            DispatchQueue.main.async {
                completion(result)
            }
        }.resume()
    }
    
    static func checkResult(data: Data?, response: URLResponse?, error: Error?) -> CheckResult {
        let result: CheckResult
        
        if let error: Error = error {
            result = CheckResult.failed(reason: error.localizedDescription)
        }
        else if let httpResponse: HTTPURLResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200:
                if let data: Data = data, let release: LatestRelease = try? JSONDecoder().decode(LatestRelease.self, from: data) {
                    let url: URL? = release.htmlURL.flatMap({ URL(string: $0) })
                    result = CheckResult.release(tagName: release.tagName, url: url, eTag: httpResponse.value(forHTTPHeaderField: "ETag"))
                }
                else {
                    result = CheckResult.failed(reason: "malformed release")
                }
            case 304:
                result = CheckResult.notModified
            case 404:
                result = CheckResult.noRelease
            default:
                result = CheckResult.failed(reason: "status \(httpResponse.statusCode)")
            }
        }
        else {
            result = CheckResult.failed(reason: "no HTTP response")
        }
        
        return result
    }
    
    // MARK: - Helpers
    /// A missing or future last check date counts as due, so a clock that moved backward cannot stop checks.
    static func isAutomaticCheckDue(isEnabled: Bool, lastCheckDate: Date?, date: Date) -> Bool {
        guard isEnabled else { return false }
        guard let lastCheckDate: Date = lastCheckDate else { return true }
        
        let elapsedTimeInterval: TimeInterval = date.timeIntervalSince(lastCheckDate)
        return elapsedTimeInterval < 0.0 || elapsedTimeInterval >= UpdateChecker.automaticCheckTimeInterval
    }
    
    /// "owner/repo" from the config's GitHub link, used by both the request and the trusted link check.
    static func repositoryPath(fromGitHubPath gitHubPath: String?) -> String? {
        guard
            let gitHubPath: String = gitHubPath,
            let url: URL = URL(string: gitHubPath),
            url.host?.lowercased() == "github.com"
        else { return nil }
        
        let components: [String] = url.pathComponents.filter({ $0 != "/" })
        guard components.count == 2 else { return nil }
        
        return components.joined(separator: "/")
    }
    
    /// Accepts only release tags in the "26.1.0" pattern, so a tag such as "v26.1.0", "27.1" or "27.1.0beta" is never offered.
    static func latestVersion(fromTag tag: String) -> String? {
        let components: [Substring] = tag.split(separator: ".", omittingEmptySubsequences: false)
        let isNumeric: Bool = components.allSatisfy({ component in
            return component.isEmpty == false && component.allSatisfy({ $0.isASCII && $0.isNumber })
        })
        guard components.count == 3, isNumeric else { return nil }
        
        return tag
    }
    
    /// Trailing zero components are ignored, so "26.1" and "26.1.0" are the same version.
    static func isNewer(_ version: String, than currentVersion: String) -> Bool {
        return trimmedVersion(version).compare(trimmedVersion(currentVersion), options: .numeric) == .orderedDescending
    }
    
    private static func trimmedVersion(_ version: String) -> String {
        var components: [Substring] = version.split(separator: ".", omittingEmptySubsequences: false)
        
        while components.count > 1, let lastComponent: Substring = components.last, Int(lastComponent) == 0 {
            components.removeLast()
        }
        
        return components.joined(separator: ".")
    }
    
    /// Only https links on github.com inside the Fanny repository, with no "..", can be opened.
    static func isTrustedReleaseURL(_ url: URL, repositoryPath: String) -> Bool {
        let standardizedURL: URL = url.standardized
        guard
            standardizedURL.scheme?.lowercased() == "https",
            standardizedURL.host?.lowercased() == "github.com",
            standardizedURL.user == nil,
            standardizedURL.password == nil,
            standardizedURL.port == nil,
            standardizedURL.pathComponents.contains("..") == false
        else { return false }
        
        return standardizedURL.path.hasPrefix("/\(repositoryPath)/")
    }
    
    /// A release link outside the repository falls back to its latest release page.
    static func availableUpdate(tagName: String, releaseURL: URL?, currentVersion: String, repositoryPath: String) -> AvailableUpdate? {
        guard
            let version: String = latestVersion(fromTag: tagName),
            isNewer(version, than: currentVersion)
        else { return nil }
        
        let url: URL?
        
        if let releaseURL: URL = releaseURL, isTrustedReleaseURL(releaseURL, repositoryPath: repositoryPath) {
            url = releaseURL
        }
        else {
            url = URL(string: "https://github.com/\(repositoryPath)/releases/latest")
        }
        
        return url.map({ AvailableUpdate(version: version, url: $0) })
    }
}

// MARK: - FannySettingsManagerDelegate
extension UpdateChecker: FannySettingsManagerDelegate {
    
    /// Checks only when automatic checks turn on, so other settings changes never retry a failed check early.
    func fannySettingsManager(_ manager: FannySettingsManager, didUpdateSettings settings: FannySettings) {
        let didTurnOn: Bool = settings.checksForUpdatesAutomatically && checksForUpdatesAutomatically == false
        checksForUpdatesAutomatically = settings.checksForUpdatesAutomatically
        
        guard didTurnOn else { return }
        checkIfNeeded()
    }
}
