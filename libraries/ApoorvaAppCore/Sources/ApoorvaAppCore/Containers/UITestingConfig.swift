//
//  UITestingConfig.swift
//  ApoorvaAppCore
//

import Foundation

/// Detects the `-UITesting` launch argument. Only honoured in DEBUG builds.
public enum UITestingConfig {
    public static let launchArgument = "-UITesting"

    public static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        false
        #endif
    }

    /// Clears persisted state so every UI test starts from a first-launch flow.
    public static func resetStateIfNeeded() {
        guard isEnabled, let domain = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }
}
