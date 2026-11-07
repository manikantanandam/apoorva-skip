//
//  DeveloperToolsTests.swift
//  ApoorvaUtilities
//

import Testing
import Foundation
@testable import ApoorvaUtilities

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

    @Test("Log buffer keeps only the newest entries")
    func testLogBuffer() {
        let buffer = LogBuffer(capacity: 2)
        buffer.append("1"); buffer.append("2"); buffer.append("3")
        #expect(buffer.entries == ["2", "3"])
        #expect(buffer.shareableText == "2\n3")
        buffer.clear()
        #expect(buffer.entries.isEmpty)
    }
}
