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

    /// Optional second argument: boot signed in to a seeded sample shop (`-UITestingSeed fancy|kirana`).
    public static let seedLaunchArgument = "-UITestingSeed"

    public static var isSeedEnabled: Bool { seedVerticalName != nil }

    /// Vertical named after the seed argument, or nil when the app should boot normally. DEBUG + `-UITesting` only.
    public static var seedVerticalName: String? {
        guard isEnabled else { return nil }
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: seedLaunchArgument) else { return nil }
        return arguments.indices.contains(index + 1) ? arguments[index + 1] : "fancy"
    }

    /// Clears persisted state so every UI test starts from a first-launch flow.
    public static func resetStateIfNeeded() {
        #if !os(Android)
        // UI tests are iOS-only; removePersistentDomain is unavailable on Android.
        guard isEnabled, let domain = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: domain)
        #endif
    }
}
