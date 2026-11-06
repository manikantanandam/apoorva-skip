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
    var isOfflineSimulated: Bool { get set }
    var showsScreenIdentifiers: Bool { get set }
}

public final class DeveloperTools: DeveloperToolsProtocol, @unchecked Sendable {
    private let defaults: UserDefaults
    private let lock = NSLock()
    private let flagsKey = "apoorva.dev.flagOverrides"
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

    public var isOfflineSimulated: Bool {
        get { defaults.bool(forKey: offlineKey) }
        set { defaults.set(newValue, forKey: offlineKey) }
    }

    public var showsScreenIdentifiers: Bool {
        get { defaults.bool(forKey: screenIdKey) }
        set { defaults.set(newValue, forKey: screenIdKey) }
    }
}

/// In-memory ring buffer of recent log lines for the in-app log viewer. Callers must not log PII.
public final class LogBuffer: @unchecked Sendable {
    private let capacity: Int
    private let lock = NSLock()
    private var lines: [String] = []

    public init(capacity: Int = 500) {
        self.capacity = capacity
    }

    public func append(_ line: String) {
        lock.lock(); defer { lock.unlock() }
        lines.append(line)
        if lines.count > capacity {
            lines.removeFirst(lines.count - capacity)
        }
    }

    public var entries: [String] {
        lock.lock(); defer { lock.unlock() }
        return lines
    }

    public var shareableText: String {
        entries.joined(separator: "\n")
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        lines.removeAll()
    }
}
