//
//  RemoteConfigCatalogDefaults.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels

/// Builds Remote Config's compiled defaults from the single local `RemoteConfigCatalog`,
/// so the key list isn't duplicated between the two. Dot-namespaced bool flags are bucketed into
/// one JSON-object default per namespace (see `FeatureFlag.remoteConfigGroupKey`) since Remote
/// Config parameter keys can't contain dots; a standalone module's one-member group has a single
/// `"enabled"` field, same bucketing.
public enum RemoteConfigCatalogDefaults {
    public static func make() -> [String: RemoteConfigDefaultValue] {
        var defaults: [String: RemoteConfigDefaultValue] = [:]
        var groupDefaults: [String: [String: Bool]] = [:]

        for definition in RemoteConfigCatalog.all {
            if let group = definition.remoteConfigGroupKey {
                groupDefaults[group, default: [:]][definition.remoteConfigFieldName] = definition.defaultBool
                continue
            }
            switch definition.kind {
            case .bool: defaults[definition.key] = .bool(definition.defaultBool)
            case .string: defaults[definition.key] = .string(definition.defaultString)
            case .number: defaults[definition.key] = .number(definition.defaultNumber)
            case .versionGate:
                // Encoding a Bool + String struct cannot fail.
                defaults[definition.key] = .json(try! JSONEncoder().encode(definition.defaultVersionGate))
            }
        }
        for (group, fields) in groupDefaults {
            // Encoding a [String: Bool] cannot fail.
            defaults[group] = .json(try! JSONEncoder().encode(fields))
        }
        return defaults
    }
}
