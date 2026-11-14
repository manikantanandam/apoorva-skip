//
//  AppUserRoleTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("AppUserRole Tests")
struct AppUserRoleTests {

    @Test("Display names")
    func displayNames() {
        #expect(AppUserRole.standard.displayName == "Standard")
        #expect(AppUserRole.admin.displayName == "Admin")
        #expect(AppUserRole.manager.displayName == "Manager")
        #expect(AppUserRole.superAdmin.displayName == "Super Admin")
    }

    @Test("Super admin uses snake_case raw value")
    func rawValue() {
        #expect(AppUserRole.superAdmin.rawValue == "super_admin")
        #expect(AppUserRole(rawValue: "super_admin") == .superAdmin)
        #expect(AppUserRole(rawValue: "unknown") == nil)
    }

    @Test("Codable round-trip")
    func codable() throws {
        for role in AppUserRole.allCases {
            let decoded = try JSONDecoder().decode(AppUserRole.self, from: JSONEncoder().encode(role))
            #expect(decoded == role)
        }
    }
}
