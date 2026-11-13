//
//  DeveloperTools.swift
//  ApoorvaUtilities
//

import Foundation

/// Local-only developer overrides. Never synced; callers gate access to debug builds / `developer` claim.
public protocol DeveloperToolsProtocol: Sendable {
    var flagOverrides: [String: Bool] { get }
    func setFlagOverride(_ key: String, value: Bool?)
    func clearFlagOverrides()
    var remoteConfigOverrides: [String: String] { get }
    func setRemoteConfigOverride(_ key: String, value: String?)
    func clearRemoteConfigOverrides()
    var isOfflineSimulated: Bool { get set }
    var showsScreenIdentifiers: Bool { get set }
}

public final class DeveloperTools: DeveloperToolsProtocol, @unchecked Sendable {
    private let defaults: UserDefaults
    private let lock = NSLock()
    private let flagsKey = "apoorva.dev.flagOverrides"
    private let remoteConfigKey = "apoorva.dev.remoteConfigOverrides"
    private let offlineKey = "apoorva.dev.offline"
    private let screenIdKey = "apoorva.dev.screenIds"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var flagOverrides: [String: Bool] {
        lock.lock(); defer { lock.unlock() }
        return defaults.dictionary(forKey: flagsKey) as? [String: Bool] ?? [:]
    }

    /// Pass `nil` to remove the override for `key`.
    public func setFlagOverride(_ key: String, value: Bool?) {
        lock.lock(); defer { lock.unlock() }
        var current = defaults.dictionary(forKey: flagsKey) as? [String: Bool] ?? [:]
        current[key] = value
        defaults.set(current, forKey: flagsKey)
    }

    public func clearFlagOverrides() {
        lock.lock(); defer { lock.unlock() }
        defaults.removeObject(forKey: flagsKey)
    }

    public var remoteConfigOverrides: [String: String] {
        lock.lock(); defer { lock.unlock() }
        return defaults.dictionary(forKey: remoteConfigKey) as? [String: String] ?? [:]
    }

    /// Pass `nil` to remove the override for `key`.
    public func setRemoteConfigOverride(_ key: String, value: String?) {
        lock.lock(); defer { lock.unlock() }
        var current = defaults.dictionary(forKey: remoteConfigKey) as? [String: String] ?? [:]
        current[key] = value
        defaults.set(current, forKey: remoteConfigKey)
    }

    public func clearRemoteConfigOverrides() {
        lock.lock(); defer { lock.unlock() }
        defaults.removeObject(forKey: remoteConfigKey)
    }

    public var isOfflineSimulated: Bool {
        get { defaults.bool(forKey: offlineKey) }
        set { defaults.set(newValue, forKey: offlineKey) }
    }

    public var showsScreenIdentifiers: Bool {
        get { defaults.bool(forKey: screenIdKey) }
        set { defaults.set(newValue, forKey: screenIdKey) }
    }
}
