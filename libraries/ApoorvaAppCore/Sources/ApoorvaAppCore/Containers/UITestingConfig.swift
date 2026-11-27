//
//  UITestingConfig.swift
//  ApoorvaAppCore
//

import Foundation

/// Detects the `-UITesting` launch argument. Only honoured in DEBUG builds.
///
/// Android never fills `ProcessInfo.arguments`, so `MainActivity` (Main.kt) copies the Maestro launch extras
/// `UITesting` / `UITestingSeed` into the `environmentKey` / `seedEnvironmentKey` environment variables instead.
public enum UITestingConfig {
    public static let launchArgument = "-UITesting"
    public static let environmentKey = "APOORVA_UITESTING"

    public static var isEnabled: Bool {
        #if DEBUG
        #if os(Android)
        ProcessInfo.processInfo.environment[environmentKey] == "true"
        #else
        ProcessInfo.processInfo.arguments.contains(launchArgument)
        #endif
        #else
        false
        #endif
    }

    /// Optional second argument: boot signed in to a seeded sample shop (`-UITestingSeed fancy|kirana`).
    public static let seedLaunchArgument = "-UITestingSeed"
    public static let seedEnvironmentKey = "APOORVA_UITESTING_SEED"

    public static var isSeedEnabled: Bool { seedVerticalName != nil }

    /// Vertical named after the seed argument, or nil when the app should boot normally. DEBUG + `-UITesting` only.
    public static var seedVerticalName: String? {
        guard isEnabled else { return nil }
        #if os(Android)
        guard let vertical = ProcessInfo.processInfo.environment[seedEnvironmentKey] else { return nil }
        return vertical.isEmpty ? "fancy" : vertical
        #else
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: seedLaunchArgument) else { return nil }
        return arguments.indices.contains(index + 1) ? arguments[index + 1] : "fancy"
        #endif
    }

    /// Clears persisted state so every UI test starts from a first-launch flow.
    public static func resetStateIfNeeded() {
        guard isEnabled, let domain = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }
}
