//
//  FlagResolverEdgeCaseTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("FeatureFlag & FlagResolver Edge Case Tests")
struct FlagResolverEdgeCaseTests {

    @Test("Flag titles are humanised")
    func titles() {
        #expect(FeatureFlag.orders.title == "Orders")
        #expect(FeatureFlag.creditSales.title == "Billing · Credit Sales")
        #expect(FeatureFlag.minAppVersion.title == "Min App Version")
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let raw = FeatureFlag.allCases.map(\.rawValue)
        #expect(Set(raw).count == raw.count)
    }

    @Test("Only auth, kill and non-bool flags are app-only")
    func appOnly() {
        #expect(FeatureFlag.authGoogle.isAppOnly)
        #expect(FeatureFlag.killSyncWrites.isAppOnly)
        #expect(FeatureFlag.minAppVersion.isAppOnly)
        #expect(!FeatureFlag.creditSales.isAppOnly)
        #expect(!FeatureFlag.orders.isAppOnly)
    }

    @Test("Defaults for non-bool value accessors")
    func nonBoolDefaults() {
        #expect(FeatureFlag.minAppVersion.defaultStringValue == "1.0.0")
        #expect(FeatureFlag.orders.defaultStringValue.isEmpty)
        #expect(FeatureFlag.orders.defaultNumberValue == 0)
        #expect(!FeatureFlag.orders.defaultVersionGateValue.enabled)
    }

    @Test("Opt-in flags ship off")
    func compiledOff() {
        for flag in [FeatureFlag.warranty, .bluetoothPrinting, .killSyncWrites, .authGoogle, .authApple, .authPhoneOTP] {
            #expect(!flag.defaultValue)
        }
    }

    @Test("App value overrides the compiled default for app-only flags")
    func appOnlyOverride() {
        let result = FlagResolver.resolve(.authGoogle, app: ["auth.google": true], org: ["auth.google": false])
        #expect(result.isOn)
        #expect(result.source == .app)
    }

    @Test("Store can switch a flag off and wins the source over later role")
    func storeThenRole() {
        let result = FlagResolver.resolve(.returns, store: ["billing.returns": false], role: ["billing.returns": false])
        #expect(!result.isOn)
        #expect(result.source == .store)
    }

    @Test("Role switches off when the store left it on")
    func roleOff() {
        let result = FlagResolver.resolve(.returns, store: ["billing.returns": true], role: ["billing.returns": false])
        #expect(!result.isOn)
        #expect(result.source == .role)
    }

    @Test("Store and role cannot switch an off flag on")
    func lowerLevelsCannotEnable() {
        let result = FlagResolver.resolve(.warranty, store: ["billing.warranty": true], role: ["billing.warranty": true])
        #expect(!result.isOn)
        #expect(result.source == .compiled)
    }

    @Test("Org value equal to the current value changes nothing")
    func orgSameValue() {
        let result = FlagResolver.resolve(.returns, org: ["billing.returns": true])
        #expect(result.isOn)
        #expect(result.source == .compiled)
    }

    @Test("Org opt-in is blocked when the app explicitly sets the flag off")
    func orgOptInBlockedByApp() {
        let result = FlagResolver.resolve(.warranty, app: ["billing.warranty": false], org: ["billing.warranty": true])
        #expect(!result.isOn)
        #expect(result.source == .app)
    }

    @Test("Org cannot re-enable what the app turned off even for default-on flags")
    func orgCannotReenable() {
        let result = FlagResolver.resolve(.returns, app: ["billing.returns": false], org: ["billing.returns": true])
        #expect(!result.isOn)
        #expect(result.source == .app)
    }

    @Test("Org opt-in on then store switches it off")
    func orgOnStoreOff() {
        let result = FlagResolver.resolve(.warranty, org: ["billing.warranty": true], store: ["billing.warranty": false])
        #expect(!result.isOn)
        #expect(result.source == .store)
    }

    @Test("FlagResolution and source compare by value")
    func equality() {
        #expect(FlagResolver.resolve(.orders) == FlagResolver.resolve(.orders))
        #expect(FlagSource.allCasesRawValues == ["compiled", "app", "org", "store", "role"])
    }
}

private extension FlagSource {
    static var allCasesRawValues: [String] {
        [FlagSource.compiled, .app, .org, .store, .role].map(\.rawValue)
    }
}
