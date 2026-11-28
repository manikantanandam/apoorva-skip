//
//  RemoteConfigCatalogDefaultsTests.swift
//  ApoorvaFeatureFlags
//

import Testing
import Foundation
@testable import ApoorvaFeatureFlags

struct RemoteConfigCatalogDefaultsTests {
    /// `min_app_version` is the only flag left with a flat (non-JSON) parameter — every bool
    /// flag is grouped, even a standalone one like `orders` (its own one-member JSON group).
    @Test func buildsFlatDefaultOnlyForMinAppVersion() {
        let defaults = RemoteConfigCatalogDefaults.make()
        guard case .string(let minVersion) = defaults["min_app_version"] else {
            Issue.record("expected a string default for min_app_version")
            return
        }
        #expect(minVersion == "1.0.0")

        // Nothing maps to "misc" today — it's reserved for a future ungrouped flag.
        #expect(defaults["misc"] == nil)
    }

    @Test func buildsOneJSONDefaultPerStandaloneModule() {
        let defaults = RemoteConfigCatalogDefaults.make()
        for flag in [FeatureFlag.orders, .suppliers, .expenses] {
            guard case .json(let data) = defaults[flag.rawValue] else {
                Issue.record("expected a json default for \(flag.rawValue)")
                continue
            }
            let fields = try! JSONDecoder().decode([String: Bool].self, from: data)
            #expect(fields == ["enabled": flag.defaultValue])
        }
    }

    @Test func buildsOneJSONDefaultPerDotNamespaceGroup() {
        let defaults = RemoteConfigCatalogDefaults.make()
        guard case .json(let data) = defaults["billing"] else {
            Issue.record("expected a json default for the billing group")
            return
        }
        let fields = try! JSONDecoder().decode([String: Bool].self, from: data)
        #expect(fields["hold_bills"] == FeatureFlag.holdBills.defaultValue)
        #expect(fields["warranty"] == FeatureFlag.warranty.defaultValue)
        #expect(fields.count == FeatureFlag.allCases.filter { $0.remoteConfigGroupKey == "billing" }.count)

        // No flat "billing.hold_bills" key exists anymore — it can't, Remote Config rejects dots.
        #expect(defaults[FeatureFlag.holdBills.rawValue] == nil)
    }
}

struct RemoteConfigJSONRoundTripTests {
    @Test func versionGateDefaultRoundTripsThroughJSONValue() {
        let definition = RemoteConfigKeyDefinition.versionGate("test.gate", title: "Test Gate",
                                                                 default: VersionGateValue(enabled: true, minVersion: "2.3.0"))
        let service = NoOpRemoteConfigService()
        service.setDefaults([definition.key: .json(try! JSONEncoder().encode(definition.defaultVersionGate))])

        let decoded = service.jsonValue(forKey: definition.key, as: VersionGateValue.self)
        #expect(decoded == VersionGateValue(enabled: true, minVersion: "2.3.0"))
    }

    @Test func missingKeyReturnsNil() {
        let service = NoOpRemoteConfigService()
        #expect(service.jsonValue(forKey: "missing", as: VersionGateValue.self) == nil)
    }
}
