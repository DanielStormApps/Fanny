# CLAUDE Instructions

This repository contains Fanny, a macOS menu bar app that shows fan speeds and CPU/GPU temperatures. Follow these guidelines when updating the codebase.

## Environment & Technical Stack

### Technical Requirements
* **Target macOS version:** macOS 27.0+
* **Supported Devices:** All Apple silicon Macs running macOS 27.0+ (arm64 only)
* **Xcode version:** 27.1+
* **Swift version:** 5.0
* Avoid deprecated APIs and manage dependencies with Swift Package Manager.
* **Sandboxing:** the app is NOT sandboxed (it reads the SMC through IOKit). The widget extension IS sandboxed, as WidgetKit requires.

### Apple Documentation
* For "what is the API for X" lookups, try the Xcode MCP `DocumentationSearch` tool first.
* To read a specific page in full, swap the host `developer.apple.com` for `sosumi.ai` (keep the rest of the path) to fetch the page as clean markdown. Example: `https://developer.apple.com/documentation/AppKit/NSStatusItem` becomes `https://sosumi.ai/documentation/AppKit/NSStatusItem`.

### Architecture Pattern
* MVVM is recommended.

### Building & Verification
* Don't build the project just to check that code compiles. Read and analyze the code directly instead: check for syntax errors, type mismatches, missing imports, and throwing functions.
* Builds are fine when the task itself needs one, such as resolving packages, archiving, or running the app on this Mac.

## Development Guidelines

### File Management
* Always prefer editing existing files over creating new ones.
* Never proactively create documentation files (*.md) or README files.

### File Headers
* When creating new Swift files, use the following header format, with the name of the person making the change as `[author]` (their `git config user.name`):
```swift
//
//  FileName.swift
//  fanny-macOS
//
//  Created by [author] on [date].
//  Copyright © [year] [author]. All rights reserved.
//
```
* Never change the author on an existing file's header.
* Put the target on the second line: `fanny-macOS` for the app, `fanny-shared/`, and `Magma/`, `fanny-macOS-widget-extension` for the widget, and `fanny-macOS-tests` for tests.
* Never use "Claude" or any AI assistant name in file headers; when an assistant writes the file, the author is the person it is working for.

### Git Operations
* **Never put secrets or analytics IDs in tracked files.**
* Push, pull, and tag with plain `git`. HTTPS auth for github.com goes through `gh` (it is the git credential helper), and `gh` handles GitHub-side operations such as releases and the API.
* If the remote uses SSH and authentication fails, switch to HTTPS:
  ```bash
  git remote set-url origin https://github.com/DanielStormApps/Fanny.git
  ```
* **Never use fast-forward merges.** Always create merge commits using `git merge --no-ff`.
* **Squashing a branch.** When squashing the branch's commits into one for easier review, always rebase onto the target first so any changes merged into the branch during its life are preserved. Do not use `git reset --soft <merge-base>` directly - that can drop work if the branch has merges in its history. Correct flow:
  ```bash
  git rebase <target>         # replay our commits on top of target; flattens any merges, drops cherry-picked duplicates
  git reset --soft <target>   # collapse the rebased commits into the index
  git commit                  # one commit with all our work
  git push --force-with-lease # safer than --force; rejects the push if the remote advanced under us
  ```
  Never force-push to `develop` or `master`. Always use `--force-with-lease`, never plain `--force`.

## Shared Code (Magma)

The folder **`Magma/`** (`fanny/Magma/`) contains shared macOS utilities, analytics, UI components, and extensions. This code is owned directly by this repository and can be modified freely. The SMC code also lives directly in this repository.

## Git Workflow

### Commit Messages
* Write concise messages in imperative mood (e.g., "Fix bug" not "Fixed bug").
* Keep to one line, max 72 characters.

## Project Structure

* Main directories, all under `fanny/`:
  * `fanny-macOS/` - macOS app
    * `MenuBar/` - `MenuBarController`, `MenuBarButtonContent`, `MenuReadingRows`, `MenuReadingRowView`, and `PositiveApp`
    * `Sensors/` - the core logic: `SensorReader` (reads on its own queue), `SensorMonitor` (timer, sleep and wake, snapshot, delegates), `SensorCatalog` (every known fan, CPU, and GPU key), and the pure `TemperatureSelector`
    * `Sensors/SMC/` - `SMCConnection` and `SMCKey` (the IOKit `AppleSMC` connection, key codes, and value decoding)
    * `FloatingWindow/` - the floating window's controller, panel, view controller, cards, and content
    * `DeveloperMenu/` - the Developer Menu window, opened from the wrench in About or by Option-clicking the menu bar icon: Logs (stats, share, viewer) and Sensors (every fan, CPU, and GPU key from `Sensors/SensorCatalog.swift`, with raw values). Localized like the rest of the app
    * `Settings/` - the Settings window and its panes (General, Menu Bar, Floating Window, Sensors, Appearance, Privacy, FAQ, About). `Settings/FAQ/` holds the FAQ pane, and `FannySettingsManager` and `LaunchAtLoginManager` own the saved settings and the login item
    * `Appearance/` - `AppTheme`, `AppThemeManager`, and `AppThemeSettings`
    * `Localization/` - `Localizable.xcstrings`, `InfoPlist.xcstrings`, and each locale's `.lproj`
    * `Updates/` - `UpdateChecker`, the GitHub releases check
    * `Widget/` - `WidgetRefresher`, which throttles widget reloads
    * `AppIntents/` - the Siri and Shortcuts intents and `AppShortcuts`
  * `fanny-macOS-widget-extension/` - the Fanny widget (SwiftUI, WidgetKit). `Readings/` holds the widget, provider, entry, and view
  * `fanny-shared/` - code compiled into both the app and the widget: `Readings/` (`ReadingsSnapshot`, `FanReading`, `TemperatureReading`, `ReadingFormatter`, `ReadingsTimeline`) and `Settings/` (`FannySettings`, `MenuBarLayout`, `FloatingWindowLayout`)
  * `Magma/` - Shared framework
  * `Tests/` - unit tests (`fanny-macOS-tests`)
  * `Xcode Config/` - `Signing.xcconfig`, plus `Local.example.xcconfig` to copy as the gitignored `Local.xcconfig`
* `fanny-macOS/Data/FAQ/` - the Settings FAQ. `<locale>.lproj/faq-articles.json` follows `faq-articles-schema.json`, loaded by `FAQArticleParser`. `navigationLink` destinations must be `FAQDestination` cases. Every locale keeps the same section and article ids, symbols, destinations, and block structure as en; only text differs. Validate with `python3 fanny/fanny-macOS/Data/FAQ/validate_faq.py fanny/fanny-macOS/Data/FAQ` (the folder, not `en.lproj`). Articles stay user facing and general, with no implementation details.
* Repo root: `readme-assets/` (the README image), `.github/` (issue forms and funding), and `LICENSE`
* Organize folders following the current project layout.
* Organize methods with `// MARK: -` section headers and insert one blank line before each block.

## Editing `.xcodeproj/project.pbxproj`

* Add files, groups, packages, and build settings with `xcrun xcodeproj` when it can do the job. Run `xcrun xcodeproj --help` for its commands.
* Touch **only** the minimal block you need; never rewrite or re-indent the whole file.
* Keep existing whitespace: one tab of indentation, no trailing spaces.
* Always normalize spacing exactly like Xcode would.

## Dependency Management

* Every Swift package is pinned to an exact version:
  * Firebase (https://github.com/firebase/firebase-ios-sdk, release notes: https://firebase.google.com/support/release-notes/ios) - Analytics and Crashlytics
  * TelemetryDeck (https://github.com/TelemetryDeck/SwiftSDK)
  * PureLayout (https://github.com/PureLayout/PureLayout) - the required Auto Layout library (see Code Style)
  * SFSafeSymbols (https://github.com/SFSafeSymbols/SFSafeSymbols) - type-safe SF Symbols
  * ZIPFoundation (https://github.com/weichsel/ZIPFoundation) - zips log files
* When updating, check each package for its latest stable version, bump the exact version in `project.pbxproj`, then resolve packages so `Package.resolved` picks up the new transitive versions.

## Analytics IDs

* `fanny/fanny-macOS/Config/config.json` (TelemetryDeck IDs) and `fanny/fanny-macOS/GoogleService-Info.plist` (Firebase) are gitignored. Never commit them or paste their values anywhere tracked.
* `fanny/fanny-macOS/Config/config.example.json` is committed with placeholder values. A build phase copies the real files only when they exist.

## Distribution

* Fanny ships outside the Mac App Store as a Developer ID signed, notarized build attached to a GitHub release. fannywidget.com links to `releases/latest`.
* Bundle ID: `com.fannywidget` (widget `com.fannywidget.widget`), app group `<team ID>.com.fannywidget`
* Team ID: set only in the gitignored `fanny/Xcode Config/Local.xcconfig`. `Signing.xcconfig` leaves it empty and derives the app group (`FANNY_APP_GROUP_IDENTIFIER`) from it, which reaches both entitlements files and both Info.plist files. Never write the team into `project.pbxproj`; picking a team in Signing & Capabilities does that, so set it in `Local.xcconfig` instead.
* Platform: macOS, scheme `fanny-macOS`

## Code Style

This section shows the Swift coding style used in this codebase. The ✅ examples are taken from the code itself.

### Style Rules with Examples

#### 1. Naming Conventions

Use camel-case for all identifiers (variables, functions, properties).

✅ **Good:**
```swift
let previousSnapshot: ReadingsSnapshot? = snapshot
let unit: FannySettings.TemperatureUnit = FannySettingsManager.shared.settings.temperatureUnit
let isVisibleChange: Bool = SensorMonitor.isVisibleChange(from: previousSnapshot, to: updatedSnapshot, unit: unit)

func readDiagnostics(completion: @escaping (SensorReader.Diagnostics) -> Void) {
    reader.readDiagnostics(settings: FannySettingsManager.shared.settings, completion: completion)
}
```

#### 2. Comments and Documentation

* Comments should be brief, placed above the code they describe, and only added if the code is not clear
* Add a one-sentence `///` doc comment above every public or `final` type and major helper
* Comments should explain WHY when it is not obvious. Do not restate WHAT a well-named identifier already says
* Drop comments entirely on self-evident constants and properties
* Keep comments general. Do not reference specific tickets, PRs, dates, task names, or past incidents; git history already tracks why a change was made

✅ **Good:**
```swift
/// A shared instance class that manages analytics tracking.
final class Analytics {

    private var bridges: [AnalyticsBridge] = []

    // MARK: - Init
    private init() {}
    static let shared: Analytics = Analytics()
}

/// The widget shows minutes, so an unchanged snapshot is saved again only this often to keep its date current.
private static let unchangedSnapshotSaveTimeInterval: TimeInterval = 60.0
```

#### 3. TODO Comments

TODO comments must include a 🔴 emoji prefix to make them visually stand out.

✅ **Good:**
```swift
// 🔴 TODO: Remove the temporary mock readings
```

❌ **Bad:**
```swift
// TODO: Remove the temporary mock readings
```

#### 4. No Alignment Padding for = or :

❌ **Bad:**
```swift
private static let menuRefreshTimeInterval: TimeInterval         = 1.0
private static let refreshToleranceRatio: Double                 = 0.1
private static let unchangedSnapshotSaveTimeInterval: TimeInterval = 60.0
```

✅ **Good:**
```swift
private static let menuRefreshTimeInterval: TimeInterval = 1.0
private static let refreshToleranceRatio: Double = 0.1
private static let unchangedSnapshotSaveTimeInterval: TimeInterval = 60.0
```

#### 5. Array Literal Formatting

Multiline array literals keep the opening `[` on the same line as the `=` with the first element, put each later element on its own line aligned with the first, and end with a trailing comma right before the closing `]`.

✅ **Good:**
```swift
stats = [Stat.fanSpeed,
         Stat.fanSpeedBar,
         Stat.fanTarget,
         Stat.fanMinimum,
         Stat.fanMaximum,]
```

#### 6. Final Classes

Mark classes `final` when they are not designed to be subclassed.

✅ **Good:**
```swift
/// Singleton that reads the sensors on a timer, keeps the latest snapshot, and saves it for the widget.
final class SensorMonitor {

    private let reader: SensorReader = SensorReader()
}

/// A multicast delegate for broadcasting events to multiple listeners.
final class DelegateMulticast<T> {

    private var delegates: [WeakDelegate] = []
}
```

#### 7. MARK Section Headers

Organize code with `// MARK:` section headers. Use a hyphen after the colon for major sections. MARK comments should be placed on the line immediately before the code they mark, with no empty line in between.

✅ **Good:**
```swift
// MARK: - SensorMonitorDelegate
protocol SensorMonitorDelegate: AnyObject {
    func sensorMonitor(_ monitor: SensorMonitor, didUpdateSnapshot snapshot: ReadingsSnapshot)
}

// MARK: - Init
private init() {}
static let shared: SensorMonitor = SensorMonitor()

// MARK: - View Cycle
override func viewDidLoad() {
    super.viewDidLoad()
    analytics(title: "general")
    setupRows()
}

// MARK: - Actions
@objc private func openSettings(_ sender: NSMenuItem) {
    trackAction("Settings", sender: sender)
    SettingsWindowController.shared.show()
}
```

Example of MARK with extensions:
```swift
// MARK: - FannySettingsManagerDelegate
extension SensorMonitor: FannySettingsManagerDelegate {

    func fannySettingsManager(_ manager: FannySettingsManager, didUpdateSettings settings: FannySettings) {
        // implementation
    }
}
```

❌ **Bad:**
```swift
// MARK: - View Cycle

override func viewDidLoad() {
    // Empty line between MARK and code is incorrect
}
```

Common MARK sections include:
- `// MARK: - Init` - For initializers and shared instance
- `// MARK: - Setup` - For setup/configuration methods
- `// MARK: - View Cycle` - For lifecycle methods like viewDidLoad
- `// MARK: - Actions` - For @objc action methods
- `// MARK: - Helpers` - For small static helpers, often the ones the tests call
- `// MARK: - [protocol name]` - For protocol conformance implementations

Note: Do not use `// MARK: - Properties` or `// MARK: - Constants` for basic property declarations at the top of a type. See rule 23.

#### 8. Property Declarations (One Per Line)

✅ **Good:**
```swift
struct Fan: Equatable {
    let id: Int
    let isStopped: Bool
    let currentRPM: Double
    let minimumRPM: Double?
    let maximumRPM: Double?
    let targetRPM: Double?
}

private static let leadingInset: CGFloat = 12.0
private static let imageColumnWidth: CGFloat = 18.0
private static let trailingInset: CGFloat = 16.0
```

#### 9. Early Guard Exits

Use `guard` for early exits to reduce nesting and improve readability.

✅ **Good:**
```swift
func openAvailableUpdate() {
    guard
        let availableUpdate: AvailableUpdate = availableUpdate,
        let repositoryPath: String = UpdateChecker.repositoryPath(fromGitHubPath: ConfigManager.shared.config.app?.gitHubPath),
        UpdateChecker.isTrustedReleaseURL(availableUpdate.url, repositoryPath: repositoryPath)
    else {
        Log.warn("🔄 openAvailableUpdate -> no trusted release link")
        return
    }
    // continue processing...
}

guard isMenuOpen == false else { return }
```

#### 10. Else and Catch on Their Own Line

Place `else`, `else if`, and `catch` on their own line, not on the same line as the closing brace.

❌ **Bad:**
```swift
if let data: Data = Storage.data(forKey: .fannySettings) {
    do {
        settings = try JSONDecoder().decode(FannySettings.self, from: data)
    } catch {
        settings = FannySettings()
    }
} else {
    settings = FannySettings()
}
```

✅ **Good:**
```swift
if let data: Data = Storage.data(forKey: .fannySettings) {
    do {
        settings = try JSONDecoder().decode(FannySettings.self, from: data)
    }
    catch {
        Log.error("💾 FannySettings load -> error: \(error.localizedDescription)")
        settings = FannySettings()
    }
}
else {
    settings = FannySettings()
}
```

#### 11. Weak Self Capture in Closures

Capture `self` weakly in closures to avoid retain cycles, and unwrap it as `strongSelf`. Note: In animation closures where the lifetime is guaranteed to be short, capturing self strongly is acceptable.

✅ **Good (async operations and timers - weak self required):**
```swift
reader.readSnapshot(settings: FannySettingsManager.shared.settings) { [weak self] snapshot in
    guard let strongSelf: SensorMonitor = self else { return }
    strongSelf.isReading = false
    strongSelf.handleSnapshot(snapshot)
}

let timer: Timer = Timer(timeInterval: timeInterval, repeats: true) { [weak self] _ in
    self?.refresh()
}
```

✅ **Good (Animations - short lifetime, strong self acceptable):**
```swift
NSAnimationContext.runAnimationGroup { context in
    context.duration = duration
    self.checkProgressIndicator.animator().alphaValue = isVisible ? 1.0 : 0.0
}
```

#### 12. Trailing Closures

Use trailing closures when a function has a single closure parameter or when it improves readability.

✅ **Good:**
```swift
delegate.invoke({ $0.sensorMonitor(self, didUpdateSnapshot: updatedSnapshot) })

FannySettingsManager.shared.update({ $0.showsFloatingWindow = ($0.showsFloatingWindow == false) })

// Multiple parameters with completion
NSAnimationContext.runAnimationGroup { context in
    context.duration = duration
    self.checkProgressIndicator.animator().alphaValue = isVisible ? 1.0 : 0.0
} completionHandler: {
    guard isVisible == false, self.isShowingCheckProgress == false else { return }
    self.checkProgressIndicator.stopAnimation(nil)
}

// Closure with parameters
refreshNow { snapshot in
    continuation.resume(returning: snapshot)
}
```

#### 13. Access Control

Every property and method starts as `private`. Widen it only when another type actually needs it: `private(set)` when other types only read it, and `internal` (no modifier) when they also write it or call it. Don't flag an `internal` property that another type genuinely uses.

✅ **Good:**
```swift
let delegate: DelegateMulticast<SensorMonitorDelegate> = DelegateMulticast<SensorMonitorDelegate>()

/// `nil` until the first read finishes.
private(set) var snapshot: ReadingsSnapshot?

private var isStarted: Bool = false
private var refreshTimer: Timer?

private let reader: SensorReader = SensorReader()

private static let menuRefreshTimeInterval: TimeInterval = 1.0
```

#### 14. Type Declarations

You MUST always declare types explicitly rather than relying on type inference.
Do NOT assume types. Go and confirm the type in the codebase.

✅ **Good:**
```swift
let settings: FannySettings = FannySettingsManager.shared.settings
let timeInterval: TimeInterval = SensorMonitor.refreshTimeInterval(settingsTimeInterval: FannySettingsManager.shared.settings.refreshTimeInterval, isMenuOpen: isMenuOpen)
let completions: [(ReadingsSnapshot) -> Void] = pendingCompletions

private var lastSavedDate: Date?
private var pendingCompletions: [(ReadingsSnapshot) -> Void] = []
```

#### 15. Boolean Comparisons and False Checks

Don't use `!` for false checks. Always use explicit equality comparisons with `== false`. Use guard statements for early exits when checking for false conditions.

❌ **Bad:**
```swift
guard !isStarted else { return }

if let eTag: String = eTag, !eTag.isEmpty {
    // send If-None-Match
}
```

✅ **Good:**
```swift
guard isStarted == false else { return }

if let eTag: String = eTag, eTag.isEmpty == false {
    // send If-None-Match
}

guard isStarted, isSleeping == false else { return }
```

#### 16. Lazy Properties

Use lazy properties for expensive initialization or when you need access to `self`.

✅ **Good:**
```swift
private lazy var internalConfig: Config? = {
    return configParser.config(filePath: internalConfigPath)
}()

private lazy var internalConfigPath: String = {
    guard let path: String = Bundle.main.path(forResource: "config", ofType: "json") else {
        fatalError("Missing internal config.json in bundle")
    }
    return path
}()
```

#### 17. Enum Usage

Use enums for related constants and states.

✅ **Good:**
```swift
enum TemperatureUnit: String, Codable, CaseIterable {
    case celsius
    case fahrenheit
    case kelvin
}

enum FanStatus: String, Codable {
    case fans
    case noFans
    case unavailable
}
```

#### 18. Floating Point Numbers

Always include the decimal point with at least one digit on each side for floating point literals.

❌ **Bad:**
```swift
let ratio: Double = .1
let inset: CGFloat = 12
let interval: TimeInterval = 60.
```

✅ **Good:**
```swift
private static let refreshToleranceRatio: Double = 0.1
private static let leadingInset: CGFloat = 12.0
private static let unchangedSnapshotSaveTimeInterval: TimeInterval = 60.0

case .fahrenheit: value = celsius * 9.0 / 5.0 + 32.0

return (temperature.value(in: unit) * 10.0).rounded() / 10.0
```

#### 19. Computed Properties

Computed properties should use multiline format with an explicit `return` statement. Do not use single-line implicit returns.

❌ **Bad:**
```swift
static var cpuTitle: String { String(localized: "CPU", comment: "Menu, tooltip, widget, and VoiceOver: label of the CPU temperature.") }
```

✅ **Good:**
```swift
static var cpuTitle: String {
    return String(localized: "CPU", comment: "Menu, tooltip, widget, and VoiceOver: label of the CPU temperature.")
}
```

#### 20. Function Arguments on Same Line

Keep function and initializer arguments on the same line when they fit reasonably. Do not split short argument lists across multiple lines.

❌ **Bad:**
```swift
NSWorkspace.shared.notificationCenter.addObserver(
    self,
    selector: #selector(willSleep(_:)),
    name: NSWorkspace.willSleepNotification,
    object: nil
)
```

✅ **Good:**
```swift
NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
```

#### 21. No Trailing Empty Lines in Type Bodies

Do not leave empty lines immediately before the closing brace of a class, struct, enum, or extension.

❌ **Bad:**
```swift
struct ReadingsSnapshot: Codable, Equatable {

    enum FanStatus: String, Codable {
        case fans
        case noFans
        case unavailable
    }

}
```

✅ **Good:**
```swift
struct ReadingsSnapshot: Codable, Equatable {

    enum FanStatus: String, Codable {
        case fans
        case noFans
        case unavailable
    }
}
```

#### 22. Blank Line Indentation Inside Type Bodies

Blank lines inside class, struct, enum, or extension bodies should maintain the indentation level (have trailing whitespace matching the surrounding code's indentation). This matches Xcode's default behavior.

❌ **Bad:**
```swift
final class DelegateMulticast<T> {

    private var delegates: [WeakDelegate] = []

    func add(_ delegate: T) {
        // implementation
    }
}
```

✅ **Good:**
```swift
final class DelegateMulticast<T> {
    
    private var delegates: [WeakDelegate] = []
    
    func add(_ delegate: T) {
        // implementation
    }
}
```

Note: The blank lines in the "Good" example have 4 spaces of indentation.

#### 23. Avoid MARK for Basic Property Organization

Do not use `// MARK: - Properties` or `// MARK: - Constants` at the top of a class or struct for simple property declarations. Just list properties directly. Reserve MARK comments for logical groupings like Init, Setup, Actions, and protocol conformances.

❌ **Bad:**
```swift
final class SensorMonitor {

    // MARK: - Properties
    private var isStarted: Bool = false
    private var isSleeping: Bool = false

    // MARK: - Constants
    private static let menuRefreshTimeInterval: TimeInterval = 1.0

    // MARK: - Init
    private init() {}
}
```

✅ **Good:**
```swift
final class SensorMonitor {

    private var isStarted: Bool = false
    private var isSleeping: Bool = false

    private static let menuRefreshTimeInterval: TimeInterval = 1.0

    // MARK: - Init
    private init() {}
}
```

#### 24. No Compound Assignment Operators

Do not use compound assignment operators (`+=`, `-=`, `*=`, etc.). Use explicit assignment instead.

❌ **Bad:**
```swift
text += ".\(version.patchVersion)"
x += sizes[index].width + gap
```

✅ **Good:**
```swift
text = text + ".\(version.patchVersion)"
x = x + sizes[index].width + gap
```

#### 25. Additional Guidelines

* Avoid `.init(...)` shorthand; call the type explicitly
* Align multiline calls and literals with the first argument label
* Always use PureLayout for Auto Layout constraints. Never use `NSLayoutConstraint` directly or anchor-based constraints (`view.topAnchor.constraint(equalTo:)`). Use PureLayout methods, such as `titleLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: MenuReadingRowView.leadingInset)` and `titleLabel.autoAlignAxis(toSuperviewAxis: .horizontal)`
* Vertical whitespace: add blank lines between logical property blocks and between method implementations within each `// MARK: -` group
* Ensure your line breaks and indentation match what already exists in the project

#### 26. Logging

Always use `Log` instead of `print`. Never use `print` statements in production code.

**Log Levels:**
- `Log.debug(_:)` - Development/debugging information
- `Log.info(_:)` - General informational messages
- `Log.warn(_:)` - Warning conditions
- `Log.error(_:)` - Error conditions

**Format:**
- Start with a domain-specific emoji prefix
- Use `->` to separate context from values
- Keep messages concise

**Domain Emojis:**
- 📲 Application lifecycle
- 📈 Analytics
- 💾 Storage (settings and the saved snapshot)
- 🌅 Widget refresh
- 🎛️ Settings
- 🎨 App theme and the floating window preview
- 🌀 Fans and the sensor monitor (start, sleep and wake, refresh interval, fan count)
- 🌡️ Temperatures, the SMC connection, and key discovery (sensor reads)
- 🔄 Update check
- 📖 FAQ
- ⚙️ Config
- 🛠️ Developer Menu
- 🔒 Privacy (analytics and log switches)

❌ **Bad:**
```swift
print("SensorMonitor started")
print("Error: \(error)")
Log.info("SensorMonitor: something happened")
```

✅ **Good:**
```swift
Log.info("📲 AppBootstrap runIfNeeded")
Log.info("🌀 SensorMonitor start -> refreshTimeInterval: \(settings.refreshTimeInterval)")
Log.debug("🔄 checkIfNeeded -> not due, enabled: \(isEnabled)")
Log.warn("🔄 handle -> failed, manual: \(isManual), reason: \(reason)")
Log.error("💾 FannySettings save -> error: \(error.localizedDescription)")
```

#### 27. Single Return Point in Functions

Avoid returning from within `if`/`else` blocks when not performing an early exit. Use `guard` for early exits that signal exceptional conditions. For normal control flow, declare the result variable at the top, assign it in each branch, and return once at the end.

❌ **Bad:**
```swift
func value(in unit: FannySettings.TemperatureUnit) -> Double {
    switch unit {
    case .celsius: return celsius
    case .fahrenheit: return celsius * 9.0 / 5.0 + 32.0
    case .kelvin: return celsius + 273.15
    }
}
```

✅ **Good:**
```swift
func value(in unit: FannySettings.TemperatureUnit) -> Double {
    let value: Double

    switch unit {
    case .celsius: value = celsius
    case .fahrenheit: value = celsius * 9.0 / 5.0 + 32.0
    case .kelvin: value = celsius + 273.15
    }

    return value
}
```

✅ **Good (early exit with guard):**
```swift
static func isVisibleChange(from previousSnapshot: ReadingsSnapshot?, to snapshot: ReadingsSnapshot, unit: FannySettings.TemperatureUnit) -> Bool {
    guard let previousSnapshot: ReadingsSnapshot = previousSnapshot else { return true }
    return DisplayedReadings(snapshot: previousSnapshot, unit: unit) != DisplayedReadings(snapshot: snapshot, unit: unit)
}
```
