//
//  RemoteConfigCatalogDefaults.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels

/// Builds Remote Config's compiled defaults from the single local `RemoteConfigCatalog`,
/// so the key list isn't duplicated between the two.
public enum RemoteConfigCatalogDefaults {
    public static func make() -> [String: RemoteConfigDefaultValue] {
        Dictionary(uniqueKeysWithValues: RemoteConfigCatalog.all.map { definition in
            let value: RemoteConfigDefaultValue
            switch definition.kind {
            case .bool: value = .bool(definition.defaultBool)
            case .string: value = .string(definition.defaultString)
            case .number: value = .number(definition.defaultNumber)
            case .versionGate:
                // Encoding a Bool + String struct cannot fail.
                value = .json(try! JSONEncoder().encode(definition.defaultVersionGate))
            }
            return (definition.key, value)
        })
    }
}
