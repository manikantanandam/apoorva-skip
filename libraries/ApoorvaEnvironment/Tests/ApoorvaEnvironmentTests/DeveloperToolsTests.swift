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
