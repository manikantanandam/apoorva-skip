//
//  AppConfig.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels

/// The one typed read path for app-level Remote Config. Keyed by `FeatureFlag`, so callers never
/// touch raw keys or repeat the compiled-default fallback. Built once by the app container.
public final class AppConfig: Sendable {
    private let service: RemoteConfigServicing

    public init(service: RemoteConfigServicing) {
        self.service = service
    }

    public func bool(_ flag: FeatureFlag) -> Bool {
        assert(flag.kind == .bool, "\(flag.rawValue) is not a bool flag")
        return service.boolValue(forKey: flag.rawValue)
    }

    public func string(_ flag: FeatureFlag) -> String {
        assert(flag.kind == .string, "\(flag.rawValue) is not a string flag")
        return service.stringValue(forKey: flag.rawValue) ?? flag.defaultStringValue
    }

    /// Minimum supported app version; below it the app shows the force-update screen.
    public var minAppVersion: String { string(.minAppVersion) }

    public func fetchAndActivate() async throws {
        try await service.fetchAndActivate()
    }
}
