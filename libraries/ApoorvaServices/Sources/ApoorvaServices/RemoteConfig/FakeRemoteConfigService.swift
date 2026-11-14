//
//  FakeRemoteConfigService.swift
//  ApoorvaServices
//

import Foundation

/// Offline remote config for UI tests, where Firebase is never configured. Serves only the
/// compiled defaults passed to `setDefaults`, never a remote value.
public final class FakeRemoteConfigService: RemoteConfigServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var defaults: [String: RemoteConfigDefaultValue] = [:]

    public init() {}

    public func fetchAndActivate() async throws {}

    public func boolValue(forKey key: String) -> Bool {
        if case let .bool(value) = defaultValue(key) { return value }
        return false
    }

    public func stringValue(forKey key: String) -> String? {
        if case let .string(value) = defaultValue(key) { return value }
        return nil
    }

    public func numberValue(forKey key: String) -> Double? {
        if case let .number(value) = defaultValue(key) { return value }
        return nil
    }

    public func jsonValue<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        guard case let .json(data) = defaultValue(key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    public func isRemoteValue(forKey key: String) -> Bool { false }

    public func setDefaults(_ defaults: [String: RemoteConfigDefaultValue]) {
        lock.lock()
        defer { lock.unlock() }
        self.defaults = defaults
    }

    private func defaultValue(_ key: String) -> RemoteConfigDefaultValue? {
        lock.lock()
        defer { lock.unlock() }
        return defaults[key]
    }
}
