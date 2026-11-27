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
    /// `bundle` is optional rather than defaulting to `.main`: Skip can't bridge `Bundle.main` in a default argument.
    public static func firebasePlistPath(in bundle: Bundle? = nil) -> String? {
        (bundle ?? .main).path(forResource: current.firebasePlistName, ofType: "plist")
    }
}
