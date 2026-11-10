//
//  DebugRemoteConfigOverrideServiceTests.swift
//  ApoorvaAppCore
//

import Testing
import ApoorvaServices
import ApoorvaEnvironment
@testable import ApoorvaAppCore

final class StubDeveloperTools: DeveloperToolsProtocol, @unchecked Sendable {
    var flagOverrides: [String: Bool] = [:]
    func setFlagOverride(_ key: String, value: Bool?) { flagOverrides[key] = value }
    func clearFlagOverrides() { flagOverrides = [:] }
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
}
