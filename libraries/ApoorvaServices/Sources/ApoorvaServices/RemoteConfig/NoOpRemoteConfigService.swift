//
//  NoOpRemoteConfigService.swift
//  ApoorvaServices
//

import Foundation

/// For previews and unit tests — never talks to any remote config provider.
/// Returns whatever was passed to `setDefaults`, or the type's zero value otherwise.
public final class NoOpRemoteConfigService: RemoteConfigServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var defaults: [String: RemoteConfigDefaultValue] = [:]

    public init() {}

    public func fetchAndActivate() async throws {}

    public func boolValue(forKey key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if case .bool(let value) = defaults[key] { return value }
        return false
    }

    public func stringValue(forKey key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        if case .string(let value) = defaults[key] { return value }
        return nil
    }

    public func numberValue(forKey key: String) -> Double? {
        lock.lock(); defer { lock.unlock() }
        if case .number(let value) = defaults[key] { return value }
        return nil
    }

    public func setDefaults(_ defaults: [String: RemoteConfigDefaultValue]) {
        lock.lock(); defer { lock.unlock() }
        self.defaults = defaults
    }
}
