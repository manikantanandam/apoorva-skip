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
            let raw = defaults.string(forKey: key)
            print("[EnvironmentStore] DEBUG build. raw value in defaults for key '\(key)': \(raw ?? "nil")")
            guard let raw,
                  let env = AppEnvironment(rawValue: raw) else {
                print("[EnvironmentStore] no valid stored value, falling back to defaultEnvironment: \(AppEnvironment.defaultEnvironment)")
                return AppEnvironment.defaultEnvironment
            }
            print("[EnvironmentStore] resolved stored environment: \(env)")
            return env
            #else
            print("[EnvironmentStore] non-DEBUG build, forcing .production")
            return .production
            #endif
        }
        nonmutating set {
            print("[EnvironmentStore] writing environment '\(newValue)' to key '\(key)'")
            defaults.set(newValue.rawValue, forKey: key)
        }
    }
}
