//
//  LaunchEnvironment.swift
//  ApoorvaAppCore
//

import Foundation
import ApoorvaUtilities

/// Resolves the environment chosen for this launch, before any container is built.
public enum LaunchEnvironment {
    public static var current: AppEnvironment {
        EnvironmentStore().current
    }

    /// Path of the bundled Firebase plist for a non-production environment.
    /// `nil` means "use the default `GoogleService-Info.plist`" (production, or the plist is missing).
    public static func firebasePlistPath(in bundle: Bundle = .main) -> String? {
        let environment = current
        guard environment != .production else { return nil }
        return bundle.path(forResource: environment.firebasePlistName, ofType: "plist")
    }
}
