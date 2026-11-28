//
//  AppConfigTests.swift
//  ApoorvaServices
//

import Testing
import Foundation
import ApoorvaModels
@testable import ApoorvaServices

struct AppConfigTests {
    @Test func stringFallsBackToCompiledDefaultWhenNoRemoteValue() {
        let config = AppConfig(service: NoOpRemoteConfigService())

        #expect(config.minAppVersion == FeatureFlag.minAppVersion.defaultStringValue)
    }

    @Test func stringReturnsRemoteValue() {
        let service = NoOpRemoteConfigService()
        service.setDefaults([FeatureFlag.minAppVersion.rawValue: .string("2.4.0")])
        let config = AppConfig(service: service)

        #expect(config.minAppVersion == "2.4.0")
    }

    /// `orders` has no dot namespace, so it's its own one-member group (not a flat key — every
    /// bool flag is grouped, see `everyBoolFlagIsGrouped`), with a single `"enabled"` field rather
    /// than a field named after the flag itself — room to add a second property later.
    @Test func boolReadsOwnGroupRemoteValueForModuleFlag() {
        let service = NoOpRemoteConfigService()
        service.setDefaults(["orders": .json(try! JSONEncoder().encode(["enabled": false]))])
        let config = AppConfig(service: service)

        #expect(!config.bool(.orders))
    }

    @Test func boolFallsBackToCompiledDefaultWhenModuleGroupMissing() {
        let config = AppConfig(service: NoOpRemoteConfigService())

        #expect(config.bool(.suppliers) == FeatureFlag.suppliers.defaultValue)
    }

    /// No current `FeatureFlag` is ungrouped, but `resolveBool`'s flat-key fallback is still part
    /// of its public contract — covered directly against a hand-built definition.
    @Test func resolveBoolReadsFlatKeyWhenDefinitionIsUngrouped() {
        let definition = RemoteConfigKeyDefinition.bool("standalone_flag", title: "T", default: false)
        let service = NoOpRemoteConfigService()
        service.setDefaults(["standalone_flag": .bool(true)])

        #expect(AppConfig.resolveBool(definition, from: service))
    }

    @Test func boolReadsGroupedRemoteValue() {
        let service = NoOpRemoteConfigService()
        service.setDefaults(["billing": .json(try! JSONEncoder().encode(["hold_bills": false]))])
        let config = AppConfig(service: service)

        #expect(!config.bool(.holdBills))
    }

    @Test func boolFallsBackToCompiledDefaultWhenGroupMissing() {
        let config = AppConfig(service: NoOpRemoteConfigService())

        #expect(config.bool(.holdBills) == FeatureFlag.holdBills.defaultValue)
    }

    @Test func boolFallsBackToCompiledDefaultWhenGroupMissesField() {
        let service = NoOpRemoteConfigService()
        // "billing" exists but doesn't mention "returns" — falls back to its own compiled default.
        service.setDefaults(["billing": .json(try! JSONEncoder().encode(["hold_bills": false]))])
        let config = AppConfig(service: service)

        #expect(config.bool(.returns) == FeatureFlag.returns.defaultValue)
    }

    @Test func numberFallsBackToCompiledDefaultWhenNoRemoteValue() {
        let config = AppConfig(service: NoOpRemoteConfigService())

        #expect(config.number(.syncIntervalSec) == FeatureFlag.syncIntervalSec.defaultNumberValue)
    }

    @Test func numberReadsRemoteValue() {
        let service = NoOpRemoteConfigService()
        service.setDefaults([FeatureFlag.syncIntervalSec.rawValue: .number(60)])
        let config = AppConfig(service: service)

        #expect(config.number(.syncIntervalSec) == 60)
    }
}
