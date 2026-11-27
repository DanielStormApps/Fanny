//
//  SupportMail.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Cocoa

/// Opens a support email, attaching the zipped logs when Mail can.
enum SupportMail {
    
    /// The subject used when nothing more specific applies.
    static var defaultSubject: String {
        return String(localized: "Fanny - Contact", comment: "About: contact email subject (keep app name)")
    }
    
    // MARK: - Compose
    static func compose(subject: String) {
        // A build from the public config.example.json has no address.
        guard
            let address: String = ConfigManager.shared.config.app?.contactEmailAddress,
            address.isEmpty == false
        else {
            Log.warn("🎛️ compose -> missing contact email address")
            return
        }
        
        var items: [Any] = []
        
        if let archiveURL: URL = LogArchiver.createLogArchive() {
            items.append(archiveURL)
        }
        
        // Mail can attach the logs. Without Mail set up, a plain email link still works.
        if let service: NSSharingService = NSSharingService(named: .composeEmail), service.canPerform(withItems: items) {
            service.recipients = [address]
            service.subject = subject
            service.perform(withItems: items)
        }
        else {
            var components: URLComponents = URLComponents()
            components.scheme = "mailto"
            components.path = address
            components.queryItems = [URLQueryItem(name: "subject", value: subject)]
            
            guard
                let urlString: String = components.string,
                let url: URL = URL(string: urlString)
            else {
                Log.warn("🎛️ compose -> invalid mailto link")
                return
            }
            
            if NSWorkspace.shared.open(url) == false {
                Log.warn("🎛️ compose -> failed to open mailto link")
            }
        }
    }
}
