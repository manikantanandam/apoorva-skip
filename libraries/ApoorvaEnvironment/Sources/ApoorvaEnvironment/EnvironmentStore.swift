//
//  EnvironmentStore.swift
//  ApoorvaUtilities
//

import Foundation
import ManiLogger

private let logger = AppLogger(category: .config)

/// Persists the selected `AppEnvironment` so it can be read at launch, before any container exists.
/// Release builds always resolve to production.
public struct EnvironmentStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "apoorva.selectedEnvironment"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var current: AppEnvironment {
        get {
            #if DEBUG
            let raw = defaults.string(forKey: key)
            logger.debug("DEBUG build. raw value in defaults for key '\(key)': \(raw ?? "nil")")
            guard let raw,
                  let env = AppEnvironment(rawValue: raw) else {
                logger.debug("No valid stored value, falling back to defaultEnvironment: \(AppEnvironment.defaultEnvironment)")
                return AppEnvironment.defaultEnvironment
            }
            logger.debug("Resolved stored environment: \(env)")
            return env
            #else
            logger.debug("Non-DEBUG build, forcing .production")
            return .production
            #endif
        }
        nonmutating set {
            logger.info("Writing environment '\(newValue)' to key '\(key)'")
            defaults.set(newValue.rawValue, forKey: key)
        }
    }
}
