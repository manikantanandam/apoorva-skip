//
//  DebugRemoteConfigOverrideServiceTests.swift
//  ApoorvaAppCore
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaFeatureFlags
import ApoorvaEnvironment
@testable import ApoorvaAppCore

final class StubDeveloperTools: DeveloperToolsProtocol, @unchecked Sendable {
    var remoteConfigOverrides: [String: String] = [:]
    func setRemoteConfigOverride(_ key: String, value: String?) { remoteConfigOverrides[key] = value }
    func clearRemoteConfigOverrides() { remoteConfigOverrides = [:] }
    var isOfflineSimulated = false
    var showsScreenIdentifiers = false
}

struct DebugRemoteConfigOverrideServiceTests {
    @Test func overrideWinsOverBase() {
        let base = NoOpRemoteConfigService()
        base.setDefaults(["kill.sync_writes": .bool(false), "min_app_version": .string("1.0.0")])
        let tools = StubDeveloperTools()
        tools.remoteConfigOverrides = ["kill.sync_writes": "true", "min_app_version": "2.0.0"]
        let service = DebugRemoteConfigOverrideService(base: base, developerTools: tools)

        #expect(service.boolValue(forKey: "kill.sync_writes"))
        #expect(service.stringValue(forKey: "min_app_version") == "2.0.0")
    }

    @Test func fallsBackToBaseWhenNoOverride() {
        let base = NoOpRemoteConfigService()
        base.setDefaults(["kill.sync_writes": .bool(false)])
        let service = DebugRemoteConfigOverrideService(base: base, developerTools: StubDeveloperTools())

        #expect(!service.boolValue(forKey: "kill.sync_writes"))
    }

    @Test func jsonOverrideWinsOverBase() {
        let base = NoOpRemoteConfigService()
        base.setDefaults(["test.group": .json(try! JSONEncoder().encode(["enabled": false]))])
        let tools = StubDeveloperTools()
        let overrideJSON = String(data: try! JSONEncoder().encode(["enabled": true]), encoding: .utf8)!
        tools.remoteConfigOverrides = ["test.group": overrideJSON]
        let service = DebugRemoteConfigOverrideService(base: base, developerTools: tools)

        #expect(service.jsonValue(forKey: "test.group", as: [String: Bool].self) == ["enabled": true])
    }

    @Test func jsonFallsBackToBaseWhenNoOverride() {
        let base = NoOpRemoteConfigService()
        base.setDefaults(["test.group": .json(try! JSONEncoder().encode(["enabled": false]))])
        let service = DebugRemoteConfigOverrideService(base: base, developerTools: StubDeveloperTools())

        #expect(service.jsonValue(forKey: "test.group", as: [String: Bool].self) == ["enabled": false])
    }
}
