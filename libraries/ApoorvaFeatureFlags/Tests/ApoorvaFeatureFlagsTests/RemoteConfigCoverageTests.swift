//
//  RemoteConfigCoverageTests.swift
//  ApoorvaFeatureFlags
//

import Testing
import Foundation
@testable import ApoorvaFeatureFlags

struct RemoteConfigCoverageTests {
    @Test func noOpReturnsDefaultsByType() async throws {
        let service = NoOpRemoteConfigService()
        try await service.fetchAndActivate()
        #expect(!service.boolValue(forKey: "b"))
        #expect(service.stringValue(forKey: "s") == nil)
        #expect(service.numberValue(forKey: "n") == nil)

        service.setDefaults(["b": .bool(true), "s": .string("x"), "n": .number(2), "j": .string("not json")])
        #expect(service.boolValue(forKey: "b"))
        #expect(service.stringValue(forKey: "s") == "x")
        #expect(service.numberValue(forKey: "n") == 2)
        #expect(service.jsonValue(forKey: "j", as: [String: Bool].self) == nil)
        // Wrong-typed lookups fall through to the zero value.
        #expect(!service.boolValue(forKey: "s"))
        #expect(service.stringValue(forKey: "b") == nil)
        #expect(service.numberValue(forKey: "s") == nil)
    }

    @Test func markRemoteControlsIsRemoteValue() {
        let service = NoOpRemoteConfigService()
        #expect(!service.isRemoteValue(forKey: "k"))
        service.markRemote(["k"])
        #expect(service.isRemoteValue(forKey: "k"))
    }

    @Test func appConfigFetchDelegates() async throws {
        try await AppConfig(service: NoOpRemoteConfigService()).fetchAndActivate()
    }

    @Test func catalogDefaultsCoverEveryKind() {
        let defaults = RemoteConfigCatalogDefaults.make()
        #expect(defaults.count == RemoteConfigCatalog.all.count)
        for definition in RemoteConfigCatalog.all {
            let value = defaults[definition.key]
            switch (definition.kind, value) {
            case (.bool, .bool?), (.string, .string?), (.number, .number?): break
            default: Issue.record("unexpected default type for \(definition.key)")
            }
        }
    }
}
