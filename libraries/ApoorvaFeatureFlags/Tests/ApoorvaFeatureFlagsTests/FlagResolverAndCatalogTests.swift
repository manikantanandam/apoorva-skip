//
//  FlagResolverAndCatalogTests.swift
//  ApoorvaFeatureFlags
//

import Testing
import Foundation
@testable import ApoorvaFeatureFlags

struct FlagResolverTests {
    @Test func compiledDefaultWhenNothingSet() {
        #expect(FlagResolver.resolve(.holdBills).isOn)
        #expect(FlagResolver.resolve(.holdBills).source == .compiled)
        #expect(!FlagResolver.resolve(.authGoogle).isOn)
    }

    @Test func lowerLevelsCanOnlyTurnOff() {
        let off = FlagResolver.resolve(.creditSales, org: ["billing.credit_sales": true], role: ["billing.credit_sales": false])
        #expect(!off.isOn)
        #expect(off.source == .role)

        let appOff = FlagResolver.resolve(.creditSales, app: ["billing.credit_sales": false], org: ["billing.credit_sales": true])
        #expect(!appOff.isOn)
    }

    @Test func orgCanOptIntoOffByDefaultFeatures() {
        let warranty = FlagResolver.resolve(.warranty, org: ["billing.warranty": true])
        #expect(warranty.isOn)
        #expect(warranty.source == .org)
    }

    @Test func platformDisableBeatsOrgOptIn() {
        let warranty = FlagResolver.resolve(.warranty, app: ["billing.warranty": false], org: ["billing.warranty": true])
        #expect(!warranty.isOn)
        #expect(warranty.source == .app)
    }

    @Test func appOnlyFlagsIgnoreOrgAndRole() {
        let result = FlagResolver.resolve(.authEmailPassword, org: ["auth.email_password": false])
        #expect(result.isOn)
    }
}

struct RemoteConfigCatalogTests {
    @Test func includesEveryFeatureFlagAsABoolKey() {
        let holdBills = RemoteConfigCatalog.all.first { $0.key == FeatureFlag.holdBills.rawValue }
        #expect(holdBills?.kind == .bool)
        #expect(holdBills?.defaultBool == FeatureFlag.holdBills.defaultValue)
    }

    @Test func minAppVersionIsAFeatureFlagCase() {
        #expect(FeatureFlag.allCases.contains(.minAppVersion))
        #expect(FeatureFlag.minAppVersion.kind == .string)
        #expect(FeatureFlag.minAppVersion.isAppOnly)

        let minVersion = RemoteConfigCatalog.all.first { $0.key == FeatureFlag.minAppVersion.rawValue }
        #expect(minVersion?.kind == .string)
        #expect(minVersion?.defaultString == "1.0.0")
    }

    /// Protects `AdminHomeView.featuresOn`, which only resolves non-app-only flags through
    /// `FlagResolver` (bool-only) — a non-bool flag that forgot to be app-only would break it.
    @Test func everyNonBoolFlagIsAppOnly() {
        #expect(FeatureFlag.allCases.allSatisfy { $0.kind == .bool || $0.isAppOnly })
    }

    /// Firebase Remote Config parameter keys can't contain dots — every flag's actual Remote
    /// Config parameter (its group key for dot-namespaced bool flags, its own key otherwise)
    /// must be dot-free, or creating it in the console fails outright.
    @Test func everyRemoteConfigParameterKeyIsDotFree() {
        #expect(FeatureFlag.allCases.allSatisfy { !$0.remoteConfigParameterKey.contains(".") })
    }

    /// Every bool flag shares a JSON-object group parameter (its namespace, or the `misc`
    /// catch-all) — never a flat bool parameter of its own — so a flag's Remote Config parameter
    /// never needs its `valueType` changed later, which would silently break legacy clients
    /// reading it via `boolValue(forKey:)` without a forced update.
    @Test func everyBoolFlagIsGrouped() {
        #expect(FeatureFlag.allCases.allSatisfy { $0.kind != .bool || $0.remoteConfigGroupKey != nil })
    }

    /// `orders`/`suppliers`/`expenses` are standalone app modules, not a dot-namespace — each gets
    /// its own one-member group (named after itself) with a single `"enabled"` field, rather than
    /// the generic `misc` catch-all, since a module is the more likely place to grow a second
    /// property later (e.g. a delivery-only setting on `orders`).
    @Test func standaloneModulesAreTheirOwnGroup() {
        for flag in [FeatureFlag.orders, .suppliers, .expenses] {
            #expect(flag.remoteConfigGroupKey == flag.rawValue)
            #expect(flag.remoteConfigFieldName == "enabled")
        }
        #expect(FeatureFlag.allCases.filter { $0.remoteConfigGroupKey == "misc" }.isEmpty)
    }

    @Test("Remote config value kinds list all three shapes")
    func valueKinds() {
        #expect(RemoteConfigValueKind.allCases.map(\.rawValue) == ["bool", "string", "number"])
    }
}
