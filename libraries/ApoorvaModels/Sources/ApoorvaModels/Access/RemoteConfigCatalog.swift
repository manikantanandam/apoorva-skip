//
//  RemoteConfigCatalog.swift
//  ApoorvaModels
//

import Foundation

public enum RemoteConfigValueKind: String, Sendable, CaseIterable {
    case bool, string, number
}

/// A single locally-declared Remote Config key. Create the matching parameter in the
/// Firebase console with the same key after adding it here — the compiled default below
/// keeps the app safe before the console parameter exists or has been fetched.
public struct RemoteConfigKeyDefinition: Sendable, Hashable, Identifiable {
    public let key: String
    public let title: String
    public let kind: RemoteConfigValueKind
    public let defaultBool: Bool
    public let defaultString: String
    public let defaultNumber: Double

    public var id: String { key }

    public static func bool(_ key: String, title: String, default defaultValue: Bool) -> RemoteConfigKeyDefinition {
        RemoteConfigKeyDefinition(key: key, title: title, kind: .bool, defaultBool: defaultValue, defaultString: "", defaultNumber: 0)
    }

    public static func string(_ key: String, title: String, default defaultValue: String) -> RemoteConfigKeyDefinition {
        RemoteConfigKeyDefinition(key: key, title: title, kind: .string, defaultBool: false, defaultString: defaultValue, defaultNumber: 0)
    }

    public static func number(_ key: String, title: String, default defaultValue: Double) -> RemoteConfigKeyDefinition {
        RemoteConfigKeyDefinition(key: key, title: title, kind: .number, defaultBool: false, defaultString: "", defaultNumber: defaultValue)
    }
}

public enum RemoteConfigCatalog {
    /// App-level-only values that aren't part of the `FlagResolver` org/store/role hierarchy.
    public static let nonFlagKeys: [RemoteConfigKeyDefinition] = [
        .string("min_app_version", title: "Min App Version", default: "1.0.0")
    ]

    /// Every locally declared Remote Config key: all boolean `FeatureFlag`s plus `nonFlagKeys`.
    public static let all: [RemoteConfigKeyDefinition] =
        FeatureFlag.allCases.map { .bool($0.rawValue, title: $0.title, default: $0.defaultValue) } + nonFlagKeys
}
