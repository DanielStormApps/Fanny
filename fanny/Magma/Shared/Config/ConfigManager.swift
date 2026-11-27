//
//  ConfigManager.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// A shared instance class that provides the bundled config, merged with the external config when it loads.
final class ConfigManager {
    
    var config: Config! {
        return configLock.withLock({ storedConfig })
    }
    
    private var storedConfig: Config!
    private let configLock: NSLock = NSLock()
    private var configParser: ConfigParser = ConfigParser()
    private var shouldUpdateConfig: Bool = true
    
    private lazy var internalConfig: Config? = {
        return configParser.config(filePath: internalConfigPath)
    }()
    
    private lazy var externalConfigPath: String = {
        guard
            let path: String = internalConfig?.externalConfigPath,
            let name: String = internalConfig?.app?.name?.lowercased().addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let platform: String = ConfigManager.systemName.lowercased().addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let version: String = Bundle.version.lowercased().addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else {
            fatalError("Unable to build externalConfigPath")
        }
        
        let formattedPath: String = path
            .replacingOccurrences(of: "__name__", with: name)
            .replacingOccurrences(of: "__platform__", with: platform)
            .replacingOccurrences(of: "__version__", with: version)
        
        return formattedPath
    }()
    
    private lazy var internalConfigPath: String = {
        guard let path: String = Bundle.main.path(forResource: "config", ofType: "json") else {
            fatalError("Missing internal config.json in bundle")
        }
        return path
    }()
    
    private static let systemName: String = "macOS"
    
    // MARK: - Init
    static let shared: ConfigManager = ConfigManager()
    private init() {
        setConfig(internalConfig)
    }
    
    // MARK: - Update Config
    func synchronouslyUpdateConfig(completion: (() -> Void)? = nil) {
        guard shouldUpdateConfig else { completion?(); return }
        shouldUpdateConfig = false
        
        let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
        self.loadExternalConfig {
            completion?()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(1))
    }
    
    // MARK: - Config Storage
    /// The external config can arrive on a URLSession thread while the main thread reads.
    private func setConfig(_ newConfig: Config?) {
        configLock.withLock({ storedConfig = newConfig })
    }
    
    // MARK: - External Config
    private func loadExternalConfig(completion: (() -> Void)? = nil) {
        configParser.config(path: externalConfigPath) { [weak self] (config) in
            guard
                let strongSelf: ConfigManager = self,
                let externalConfig: Config = config
            else {
                Log.warn("⚙️ loadExternalConfig -> unavailable, using the bundled config")
                completion?()
                return
            }
            
            guard let mergedConfig: Config = strongSelf.internalConfig?.merge(with: externalConfig) else {
                Log.warn("⚙️ loadExternalConfig -> merge failed, using the bundled config")
                completion?()
                return
            }
            
            strongSelf.setConfig(mergedConfig)
            Log.info("⚙️ loadExternalConfig -> merged")
            completion?()
        }
    }
}
