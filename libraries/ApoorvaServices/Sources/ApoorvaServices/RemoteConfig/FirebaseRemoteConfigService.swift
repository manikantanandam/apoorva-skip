//
//  FirebaseRemoteConfigService.swift
//  ApoorvaServices
//

import Foundation
import FirebaseRemoteConfig
import ApoorvaModels
import ManiLogger

private let logger = AppLogger(category: .config)

public final class FirebaseRemoteConfigService: RemoteConfigServicing {

    /// - Parameter minimumFetchInterval: seconds a fetched template is cached before the next fetch
    ///   hits the network. Firebase's default is 12 hours; pass 0 to always fetch (debug builds).
    public init(minimumFetchInterval: TimeInterval = 43_200) {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = minimumFetchInterval
        RemoteConfig.remoteConfig().configSettings = settings
    }

    public func fetchAndActivate() async throws {
        logger.info("Remote Config fetch started")
        let start = Date()
        do {
            let status = try await RemoteConfig.remoteConfig().fetchAndActivate()
            logger.info("Remote Config fetch finished: status=\(Self.describe(status)) duration=\(Self.milliseconds(since: start))ms")
            logger.info(RemoteConfigLogFormatter.summary(resolvedEntries()))
        } catch {
            logger.error("Remote Config fetch failed: \(error.localizedDescription) duration=\(Self.milliseconds(since: start))ms")
            throw error
        }
    }

    private func resolvedEntries() -> [RemoteConfigLogEntry] {
        let remoteConfig = RemoteConfig.remoteConfig()
        var entries = RemoteConfigCatalog.all.map { definition -> RemoteConfigLogEntry in
            let value = remoteConfig.configValue(forKey: definition.key)
            let text: String
            switch definition.kind {
            case .bool: text = String(value.boolValue)
            case .string, .versionGate: text = value.stringValue
            case .number: text = String(value.numberValue.doubleValue)
            }
            return RemoteConfigLogEntry(key: definition.key, value: text, source: Self.source(of: value))
        }
        // Raw keys Firebase returned, including any the app doesn't know (e.g. a misnamed console parameter).
        let known = Set(RemoteConfigCatalog.all.map(\.key))
        for key in remoteConfig.allKeys(from: .remote).sorted() where !known.contains(key) {
            entries.append(RemoteConfigLogEntry(key: key, value: remoteConfig.configValue(forKey: key).stringValue,
                                                source: .remote, isInCatalogue: false))
        }
        return entries
    }

    private static func source(of value: RemoteConfigValue) -> RemoteConfigValueSource {
        switch value.source {
        case .remote: return .remote
        case .default: return .default
        case .static: return .static
        @unknown default: return .static
        }
    }

    private static func describe(_ status: RemoteConfigFetchAndActivateStatus) -> String {
        switch status {
        case .successFetchedFromRemote: return "fetchedFromRemote"
        case .successUsingPreFetchedData: return "usingPreFetchedData"
        case .error: return "error"
        @unknown default: return "unknown"
        }
    }

    private static func milliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }

    public func boolValue(forKey key: String) -> Bool {
        RemoteConfig.remoteConfig().configValue(forKey: key).boolValue
    }

    public func stringValue(forKey key: String) -> String? {
        RemoteConfig.remoteConfig().configValue(forKey: key).stringValue
    }

    public func numberValue(forKey key: String) -> Double? {
        RemoteConfig.remoteConfig().configValue(forKey: key).numberValue.doubleValue
    }

    public func jsonValue<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        let data = RemoteConfig.remoteConfig().configValue(forKey: key).dataValue
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func isRemoteValue(forKey key: String) -> Bool {
        RemoteConfig.remoteConfig().configValue(forKey: key).source == .remote
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
        RemoteConfig.remoteConfig().setDefaults(bridged)
    }
}
