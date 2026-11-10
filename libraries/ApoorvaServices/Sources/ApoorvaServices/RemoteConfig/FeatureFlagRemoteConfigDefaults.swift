//
//  FeatureFlagRemoteConfigDefaults.swift
//  ApoorvaServices
//

import ApoorvaModels

/// Builds Remote Config's compiled defaults from the single `FeatureFlag` catalogue (docs/05),
/// so the flag list isn't duplicated between the two.
public enum FeatureFlagRemoteConfigDefaults {
    public static func make() -> [String: RemoteConfigDefaultValue] {
        Dictionary(uniqueKeysWithValues: FeatureFlag.allCases.map { ($0.rawValue, .bool($0.defaultValue)) })
    }
}
