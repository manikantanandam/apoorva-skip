//
//  DeveloperToolsTests.swift
//  ApoorvaUtilities
//

import Testing
import Foundation
@testable import ApoorvaEnvironment

@Suite("DeveloperTools Test", .serialized)
struct DeveloperToolsTests {

    private func makeTools() throws -> DeveloperTools {
        let defaults = try #require(UserDefaults(suiteName: "DeveloperToolsTests"))
        defaults.removePersistentDomain(forName: "DeveloperToolsTests")
        return DeveloperTools(defaults: defaults)
    }

    @Test("Flag overrides can be set, removed and cleared")
    func testFlagOverrides() throws {
        let tools = try makeTools()
        tools.setFlagOverride("a", value: true)
        tools.setFlagOverride("b", value: false)
        #expect(tools.flagOverrides == ["a": true, "b": false])
        tools.setFlagOverride("a", value: nil)
        #expect(tools.flagOverrides == ["b": false])
        tools.clearFlagOverrides()
        #expect(tools.flagOverrides.isEmpty)
    }

    @Test("Toggles persist")
    func testToggles() throws {
        var tools = try makeTools()
        #expect(!tools.isOfflineSimulated)
        tools.isOfflineSimulated = true
        tools.showsScreenIdentifiers = true
        #expect(tools.isOfflineSimulated)
        #expect(tools.showsScreenIdentifiers)
    }
}
