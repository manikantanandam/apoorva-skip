//
//  RemoteConfigCatalog.swift
//  ApoorvaFeatureFlags
//

import Foundation
import ApoorvaModels

public enum RemoteConfigValueKind: String, Sendable, CaseIterable {
    case bool, string, number
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

    public var id: String { key }

    /// Mirrors `FeatureFlag.remoteConfigGroupKey`/`remoteConfigFieldName`/`remoteConfigParameterKey`
    /// (`key` here is always a flag's rawValue, so the derivation is identical) — kept here too so
    /// code working from the catalogue doesn't need the originating `FeatureFlag` case.
    public var remoteConfigGroupKey: String? {
        guard kind == .bool else { return nil }
        if let dot = key.firstIndex(of: ".") { return String(key[..<dot]) }
        // A standalone app module is its own group, keyed `{"enabled": Bool}` — see `remoteConfigFieldName`.
        if Self.moduleKeys.contains(key) { return key }
        // "misc" is reserved for a future ungrouped flag — nothing lives here today.
        return "misc"
    }

    public var remoteConfigFieldName: String {
        if Self.moduleKeys.contains(key) { return "enabled" }
        guard let dot = key.firstIndex(of: ".") else { return key }
        return String(key[key.index(after: dot)...])
    }

    public var remoteConfigParameterKey: String { remoteConfigGroupKey ?? key }

    private static let moduleKeys: Set<String> = ["orders", "suppliers", "expenses"]

    public init(key: String, title: String, kind: RemoteConfigValueKind, defaultBool: Bool, defaultString: String,
                defaultNumber: Double) {
        self.key = key
        self.title = title
        self.kind = kind
        self.defaultBool = defaultBool
        self.defaultString = defaultString
        self.defaultNumber = defaultNumber
    }

    public static func bool(_ key: String, title: String, default defaultValue: Bool) -> RemoteConfigKeyDefinition {
        RemoteConfigKeyDefinition(key: key, title: title, kind: .bool, defaultBool: defaultValue, defaultString: "",
                                   defaultNumber: 0)
    }

    public static func string(_ key: String, title: String, default defaultValue: String) -> RemoteConfigKeyDefinition {
        RemoteConfigKeyDefinition(key: key, title: title, kind: .string, defaultBool: false, defaultString: defaultValue,
                                   defaultNumber: 0)
    }

    public static func number(_ key: String, title: String, default defaultValue: Double) -> RemoteConfigKeyDefinition {
        RemoteConfigKeyDefinition(key: key, title: title, kind: .number, defaultBool: false, defaultString: "",
                                   defaultNumber: defaultValue)
    }

    public init(flag: FeatureFlag) {
        switch flag.kind {
        case .bool:
            self = .bool(flag.rawValue, title: flag.title, default: flag.defaultValue)
        case .string:
            self = .string(flag.rawValue, title: flag.title, default: flag.defaultStringValue)
        case .number:
            self = .number(flag.rawValue, title: flag.title, default: flag.defaultNumberValue)
        }
    }
}

public enum RemoteConfigCatalog {
    /// Every locally declared Remote Config key — a pure mapping over `FeatureFlag.allCases`.
    public static let all: [RemoteConfigKeyDefinition] = FeatureFlag.allCases.map(RemoteConfigKeyDefinition.init(flag:))
}
