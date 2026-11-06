//
//  AppEnvironmentTests.swift
//  ApoorvaUtilities
//

import Testing
import Foundation
@testable import ApoorvaUtilities

@Suite("AppEnvironment Test")
struct AppEnvironmentTests {

    @Test("Badge is nil only for production")
    func testBadge() {
        #expect(AppEnvironment.dev.badge == "DEV")
        #expect(AppEnvironment.staging.badge == "STG")
        #expect(AppEnvironment.production.badge == nil)
    }

    @Test("DB file name is per environment and org")
    func testDbFileName() {
        #expect(AppEnvironment.dev.dbFileName() == "apoorva-dev.db")
        #expect(AppEnvironment.staging.dbFileName(orgId: "org1") == "apoorva-staging-org1.db")
        #expect(AppEnvironment.production.dbFileName(orgId: "") == "apoorva-production.db")
    }

    @Test("Destructive tools are disabled on production")
    func testDestructiveTools() {
        #expect(AppEnvironment.dev.allowsDestructiveTools)
        #expect(AppEnvironment.staging.allowsDestructiveTools)
        #expect(!AppEnvironment.production.allowsDestructiveTools)
    }

    #if DEBUG
    @Test("Store persists selection and falls back to default")
    func testStore() throws {
        let defaults = try #require(UserDefaults(suiteName: "AppEnvironmentTests"))
        defaults.removePersistentDomain(forName: "AppEnvironmentTests")
        let store = EnvironmentStore(defaults: defaults)
        #expect(store.current == AppEnvironment.defaultEnvironment)
        store.current = .staging
        #expect(EnvironmentStore(defaults: defaults).current == .staging)
        defaults.removePersistentDomain(forName: "AppEnvironmentTests")
    }
    #endif
}
