//
//  LaunchEnvironment.swift
//  ApoorvaAppCore
//

import Foundation
import ApoorvaUtilities
import ApoorvaEnvironment

/// Resolves the environment chosen for this launch, before any container is built.
public enum LaunchEnvironment {
    public static var current: AppEnvironment {
        EnvironmentStore().current
    }

    /// Path of the bundled Firebase plist for the current environment.
    /// `nil` means the plist is missing from the bundle.
    public static func firebasePlistPath(in bundle: Bundle = .main) -> String? {
        bundle.path(forResource: current.firebasePlistName, ofType: "plist")
    }
}
