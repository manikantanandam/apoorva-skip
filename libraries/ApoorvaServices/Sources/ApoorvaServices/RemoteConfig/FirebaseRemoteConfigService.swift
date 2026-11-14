//
//  FirebaseRemoteConfigService.swift
//  ApoorvaServices
//

import Foundation
import FirebaseRemoteConfig
import ApoorvaModels
import ManiLogger

private let logger = AppLogger(category: .config)

/// One resolved Remote Config value, detached from the SDK's `RemoteConfigValue`.
struct RemoteConfigValueInfo: Sendable {
    let bool: Bool
    let string: String
    let number: Double
    let data: Data
    let source: RemoteConfigValueSource
}

enum RemoteConfigFetchStatus: Sendable {
    case fetchedFromRemote
    case usingPreFetchedData
    case error
}

/// Thin seam over `FirebaseRemoteConfig` so the service's logic can be tested without Firebase.
protocol RemoteConfigBackend: Sendable {
    func configure(minimumFetchInterval: TimeInterval)
    func fetchAndActivate() async throws -> RemoteConfigFetchStatus
    func value(forKey key: String) -> RemoteConfigValueInfo
    /// Keys the server returned (not compiled defaults).
    func remoteKeys() -> [String]
    func setDefaults(_ defaults: [String: NSObject])
}

public final class FirebaseRemoteConfigService: RemoteConfigServicing {

    private let backend: RemoteConfigBackend

    /// - Parameter minimumFetchInterval: seconds a fetched template is cached before the next fetch
    ///   hits the network. Firebase's default is 12 hours; pass 0 to always fetch (debug builds).
    public convenience init(minimumFetchInterval: TimeInterval = 43_200) {
        self.init(backend: FirebaseRemoteConfigBackend(), minimumFetchInterval: minimumFetchInterval)
    }

    init(backend: RemoteConfigBackend, minimumFetchInterval: TimeInterval = 43_200) {
        self.backend = backend
        backend.configure(minimumFetchInterval: minimumFetchInterval)
    }

    public func fetchAndActivate() async throws {
        logger.info("Remote Config fetch started")
        let start = Date()
        do {
            let status = try await backend.fetchAndActivate()
            logger.info("Remote Config fetch finished: status=\(Self.describe(status)) duration=\(Self.milliseconds(since: start))ms")
            logger.info(RemoteConfigLogFormatter.summary(resolvedEntries()))
        } catch {
            logger.error("Remote Config fetch failed: \(error.localizedDescription) duration=\(Self.milliseconds(since: start))ms")
            throw error
        }
    }

    func resolvedEntries() -> [RemoteConfigLogEntry] {
        var entries = RemoteConfigCatalog.all.map { definition -> RemoteConfigLogEntry in
            let value = backend.value(forKey: definition.key)
            let text: String
            switch definition.kind {
            case .bool: text = String(value.bool)
            case .string, .versionGate: text = value.string
            case .number: text = String(value.number)
            }
            return RemoteConfigLogEntry(key: definition.key, value: text, source: value.source)
        }
        // Raw keys Firebase returned, including any the app doesn't know (e.g. a misnamed console parameter).
        let known = Set(RemoteConfigCatalog.all.map(\.key))
        for key in backend.remoteKeys().sorted() where !known.contains(key) {
            entries.append(RemoteConfigLogEntry(key: key, value: backend.value(forKey: key).string,
                                                source: .remote, isInCatalogue: false))
        }
        return entries
    }

    static func describe(_ status: RemoteConfigFetchStatus) -> String {
        switch status {
        case .fetchedFromRemote: return "fetchedFromRemote"
        case .usingPreFetchedData: return "usingPreFetchedData"
        case .error: return "error"
        }
    }

    private static func milliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }

    public func boolValue(forKey key: String) -> Bool {
        backend.value(forKey: key).bool
    }

    public func stringValue(forKey key: String) -> String? {
        backend.value(forKey: key).string
    }

    public func numberValue(forKey key: String) -> Double? {
        backend.value(forKey: key).number
    }

    public func jsonValue<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        try? JSONDecoder().decode(T.self, from: backend.value(forKey: key).data)
    }

    public func isRemoteValue(forKey key: String) -> Bool {
        backend.value(forKey: key).source == .remote
    }

    public func setDefaults(_ defaults: [String: RemoteConfigDefaultValue]) {
        var bridged: [String: NSObject] = [:]
        for (key, value) in defaults {
            switch value {
            case .bool(let bool): bridged[key] = bool as NSNumber
            case .string(let string): bridged[key] = string as NSString
            case .number(let number): bridged[key] = number as NSNumber
            case .json(let data): bridged[key] = data as NSData
            }
        }
        backend.setDefaults(bridged)
    }
}

// MARK: - Firebase adapter (SDK calls only, no logic)

struct FirebaseRemoteConfigBackend: RemoteConfigBackend {

    func configure(minimumFetchInterval: TimeInterval) {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = minimumFetchInterval
        RemoteConfig.remoteConfig().configSettings = settings
    }

    func fetchAndActivate() async throws -> RemoteConfigFetchStatus {
        switch try await RemoteConfig.remoteConfig().fetchAndActivate() {
        case .successFetchedFromRemote: return .fetchedFromRemote
        case .successUsingPreFetchedData: return .usingPreFetchedData
        case .error: return .error
        @unknown default: return .error
        }
    }

    func value(forKey key: String) -> RemoteConfigValueInfo {
        let value = RemoteConfig.remoteConfig().configValue(forKey: key)
        let source: RemoteConfigValueSource
        switch value.source {
        case .remote: source = .remote
        case .default: source = .default
        case .static: source = .static
        @unknown default: source = .static
        }
        return RemoteConfigValueInfo(bool: value.boolValue, string: value.stringValue,
                                     number: value.numberValue.doubleValue, data: value.dataValue, source: source)
    }

    func remoteKeys() -> [String] {
        Array(RemoteConfig.remoteConfig().allKeys(from: .remote))
    }

    func setDefaults(_ defaults: [String: NSObject]) {
        RemoteConfig.remoteConfig().setDefaults(defaults)
    }
}
