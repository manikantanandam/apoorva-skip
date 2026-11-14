//
//  RemoteConfigKeyDefinitionTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("RemoteConfigKeyDefinition Tests")
struct RemoteConfigKeyDefinitionTests {

    @Test("Bool factory")
    func boolFactory() {
        let def = RemoteConfigKeyDefinition.bool("k", title: "T", default: true)
        #expect(def.id == "k")
        #expect(def.kind == .bool)
        #expect(def.defaultBool)
        #expect(def.defaultString.isEmpty)
        #expect(def.defaultNumber == 0)
        #expect(!def.defaultVersionGate.enabled)
    }

    @Test("String factory")
    func stringFactory() {
        let def = RemoteConfigKeyDefinition.string("k", title: "T", default: "1.0.0")
        #expect(def.kind == .string)
        #expect(def.defaultString == "1.0.0")
        #expect(!def.defaultBool)
    }

    @Test("Number factory")
    func numberFactory() {
        let def = RemoteConfigKeyDefinition.number("k", title: "T", default: 7.5)
        #expect(def.kind == .number)
        #expect(def.defaultNumber == 7.5)
    }

    @Test("Version gate factory")
    func versionGateFactory() {
        let gate = VersionGateValue(enabled: true, minVersion: "2.0.0")
        let def = RemoteConfigKeyDefinition.versionGate("k", title: "T", default: gate)
        #expect(def.kind == .versionGate)
        #expect(def.defaultVersionGate == gate)
    }

    @Test("Catalog has one definition per flag with matching key, title and kind")
    func catalogMatchesFlags() {
        #expect(RemoteConfigCatalog.all.count == FeatureFlag.allCases.count)
        for flag in FeatureFlag.allCases {
            let def = RemoteConfigKeyDefinition(flag: flag)
            #expect(def.key == flag.rawValue)
            #expect(def.title == flag.title)
            #expect(def.kind == flag.kind)
            switch flag.kind {
            case .bool: #expect(def.defaultBool == flag.defaultValue)
            case .string: #expect(def.defaultString == flag.defaultStringValue)
            case .number: #expect(def.defaultNumber == flag.defaultNumberValue)
            case .versionGate: #expect(def.defaultVersionGate == flag.defaultVersionGateValue)
            }
        }
    }

    @Test("Catalog keys are unique")
    func uniqueKeys() {
        let keys = RemoteConfigCatalog.all.map(\.key)
        #expect(Set(keys).count == keys.count)
    }

    @Test("VersionGateValue round-trips through Codable")
    func gateCodable() throws {
        let gate = VersionGateValue(enabled: true, minVersion: "1.2.0")
        let decoded = try JSONDecoder().decode(VersionGateValue.self, from: JSONEncoder().encode(gate))
        #expect(decoded == gate)
    }
}
