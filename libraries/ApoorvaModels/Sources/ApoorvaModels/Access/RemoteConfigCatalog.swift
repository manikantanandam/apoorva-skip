//
//  RemoteConfigCatalog.swift
//  ApoorvaModels
//

import Foundation

public enum RemoteConfigValueKind: String, Sendable, CaseIterable {
    case bool, string, number, versionGate
}

/// A version-gated feature: on only once the running app is at or above `minVersion`.
public struct VersionGateValue: Sendable, Hashable, Codable {
    public let enabled: Bool
    public let minVersion: String?

    public init(enabled: Bool, minVersion: String? = nil) {
        self.enabled = enabled
        self.minVersion = minVersion
    }

    public func isOn(currentAppVersion: String) -> Bool {
        guard enabled else { return false }
        guard let minVersion else { return true }
        return AppVersion(currentAppVersion) >= AppVersion(minVersion)
    }
}

/// A single locally-declared Remote Config key, derived from `FeatureFlag` — the single source
/// of truth. Create the matching parameter in the Firebase console with the same key after
/// adding the case to `FeatureFlag` — the compiled default below keeps the app safe before the
/// console parameter exists or has been fetched.
public struct RemoteConfigKeyDefinition: Sendable, Hashable, Identifiable {
    public let key: String
    public let title: String
    public let kind: RemoteConfigValueKind
    public let defaultBool: Bool
    public let defaultString: String
    public let defaultNumber: Double
    public let defaultVersionGate: VersionGateValue

    public var id: String { key }

    public init(key: String, title: String, kind: RemoteConfigValueKind, defaultBool: Bool, defaultString: String,
                defaultNumber: Double, defaultVersionGate: VersionGateValue) {
        self.key = key
        self.title = title
        self.kind = kind
        self.defaultBool = defaultBool
        self.defaultString = defaultString
        self.defaultNumber = defaultNumber
        self.defaultVersionGate = defaultVersionGate
    }

    public static func bool(_ key: String, title: String, default defaultValue: Bool) -> RemoteConfigKeyDefinition {
        RemoteConfigKeyDefinition(key: key, title: title, kind: .bool, defaultBool: defaultValue, defaultString: "",
                                   defaultNumber: 0, defaultVersionGate: VersionGateValue(enabled: false))
    }

    public static func string(_ key: String, title: String, default defaultValue: String) -> RemoteConfigKeyDefinition {
        RemoteConfigKeyDefinition(key: key, title: title, kind: .string, defaultBool: false, defaultString: defaultValue,
                                   defaultNumber: 0, defaultVersionGate: VersionGateValue(enabled: false))
    }

    public static func number(_ key: String, title: String, default defaultValue: Double) -> RemoteConfigKeyDefinition {
        RemoteConfigKeyDefinition(key: key, title: title, kind: .number, defaultBool: false, defaultString: "",
                                   defaultNumber: defaultValue, defaultVersionGate: VersionGateValue(enabled: false))
    }

    public static func versionGate(_ key: String, title: String, default defaultValue: VersionGateValue) -> RemoteConfigKeyDefinition {
        RemoteConfigKeyDefinition(key: key, title: title, kind: .versionGate, defaultBool: false, defaultString: "",
                                   defaultNumber: 0, defaultVersionGate: defaultValue)
    }

    public init(flag: FeatureFlag) {
        switch flag.kind {
        case .bool:
            self = .bool(flag.rawValue, title: flag.title, default: flag.defaultValue)
        case .string:
            self = .string(flag.rawValue, title: flag.title, default: flag.defaultStringValue)
        case .number:
            self = .number(flag.rawValue, title: flag.title, default: flag.defaultNumberValue)
        case .versionGate:
            self = .versionGate(flag.rawValue, title: flag.title, default: flag.defaultVersionGateValue)
        }
    }
}

public enum RemoteConfigCatalog {
    /// Every locally declared Remote Config key — a pure mapping over `FeatureFlag.allCases`.
    public static let all: [RemoteConfigKeyDefinition] = FeatureFlag.allCases.map(RemoteConfigKeyDefinition.init(flag:))
}
