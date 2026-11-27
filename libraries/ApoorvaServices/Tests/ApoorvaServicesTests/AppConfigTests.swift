//
//  AppConfigTests.swift
//  ApoorvaServices
//

import Testing
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

    @Test func boolReadsRemoteValue() {
        let service = NoOpRemoteConfigService()
        service.setDefaults([FeatureFlag.holdBills.rawValue: .bool(true)])
        let config = AppConfig(service: service)

        #expect(config.bool(.holdBills))
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
