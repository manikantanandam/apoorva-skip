//
//  FirebaseRemoteConfigService.swift
//  ApoorvaServices
//

import FirebaseRemoteConfig

public final class FirebaseRemoteConfigService: RemoteConfigServicing {

    public init() {}

    public func fetchAndActivate() async throws {
        _ = try await RemoteConfig.remoteConfig().fetchAndActivate()
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

    public func setDefaults(_ defaults: [String: RemoteConfigDefaultValue]) {
        var bridged: [String: NSObject] = [:]
        for (key, value) in defaults {
            switch value {
            case .bool(let bool): bridged[key] = bool as NSNumber
            case .string(let string): bridged[key] = string as NSString
            case .number(let number): bridged[key] = number as NSNumber
            }
        }
        RemoteConfig.remoteConfig().setDefaults(bridged)
    }
}
