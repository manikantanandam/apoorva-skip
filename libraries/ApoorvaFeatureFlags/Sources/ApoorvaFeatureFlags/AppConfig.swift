//
//  AppConfig.swift
//  ApoorvaFeatureFlags
//

import Foundation

/// The one typed read path for app-level Remote Config. Keyed by `FeatureFlag`, so callers never
/// touch raw keys or repeat the compiled-default fallback. Built once by the app container.
public final class AppConfig: Sendable {
    private let service: RemoteConfigServicing

    public init(service: RemoteConfigServicing) {
        self.service = service
    }

    public func bool(_ flag: FeatureFlag) -> Bool {
        assert(flag.kind == .bool)
        return Self.resolveBool(RemoteConfigKeyDefinition(flag: flag), from: service)
    }

    /// Group-aware bool read, shared with `FlagOverridesViewModel` so the group-decode logic
    /// isn't duplicated: grouped flags live in a shared JSON-object Remote Config parameter (see
    /// `FeatureFlag.remoteConfigGroupKey`), ungrouped flags are a flat bool key.
    public static func resolveBool(_ definition: RemoteConfigKeyDefinition, from service: RemoteConfigServicing) -> Bool {
        guard let group = definition.remoteConfigGroupKey else {
            return service.boolValue(forKey: definition.key)
        }
        let values = service.jsonValue(forKey: group, as: [String: Bool].self) ?? [:]
        return values[definition.remoteConfigFieldName] ?? definition.defaultBool
    }

    public func string(_ flag: FeatureFlag) -> String {
        assert(flag.kind == .string)
        return service.stringValue(forKey: flag.rawValue) ?? flag.defaultStringValue
    }

    public func number(_ flag: FeatureFlag) -> Double {
        assert(flag.kind == .number)
        return service.numberValue(forKey: flag.rawValue) ?? flag.defaultNumberValue
    }

    /// Minimum supported app version; below it the app shows the force-update screen.
    public var minAppVersion: String { string(.minAppVersion) }

    public func fetchAndActivate() async throws {
        try await service.fetchAndActivate()
    }
}
