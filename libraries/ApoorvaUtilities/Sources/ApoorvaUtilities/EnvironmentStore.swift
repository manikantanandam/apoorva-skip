//
//  EnvironmentStore.swift
//  ApoorvaUtilities
//

import Foundation

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
            guard let raw = defaults.string(forKey: key),
                  let env = AppEnvironment(rawValue: raw) else {
                return AppEnvironment.defaultEnvironment
            }
            return env
            #else
            return .production
            #endif
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: key)
        }
    }
}
