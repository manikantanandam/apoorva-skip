//
//  DebugRemoteConfigOverrideService.swift
//  ApoorvaAppCore
//

import Foundation
import ApoorvaServices
import ApoorvaEnvironment

/// Wraps a `RemoteConfigServicing` with local, debug-only overrides from `DeveloperTools`.
/// Overrides are stored as strings and never synced; a missing override falls back to `base`.
/// Composed only in `#if DEBUG` builds — see `AppContainer`.
public final class DebugRemoteConfigOverrideService: RemoteConfigServicing {
    private let base: RemoteConfigServicing
    private let developerTools: DeveloperToolsProtocol

    public init(base: RemoteConfigServicing, developerTools: DeveloperToolsProtocol) {
        self.base = base
        self.developerTools = developerTools
    }

    public func fetchAndActivate() async throws {
        try await base.fetchAndActivate()
    }

    public func boolValue(forKey key: String) -> Bool {
        if let override = developerTools.remoteConfigOverrides[key], let bool = Bool(override) {
            return bool
        }
        return base.boolValue(forKey: key)
    }

    public func stringValue(forKey key: String) -> String? {
        developerTools.remoteConfigOverrides[key] ?? base.stringValue(forKey: key)
    }

    public func numberValue(forKey key: String) -> Double? {
        if let override = developerTools.remoteConfigOverrides[key], let number = Double(override) {
            return number
        }
        return base.numberValue(forKey: key)
    }

    public func jsonValue<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        if let override = developerTools.remoteConfigOverrides[key],
           let data = override.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        return base.jsonValue(forKey: key, as: type)
    }

    public func isRemoteValue(forKey key: String) -> Bool {
        base.isRemoteValue(forKey: key)
    }

    public func setDefaults(_ defaults: [String: RemoteConfigDefaultValue]) {
        base.setDefaults(defaults)
    }
}
