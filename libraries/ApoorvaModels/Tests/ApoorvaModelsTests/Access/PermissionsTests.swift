//
//  PermissionsTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("Permissions Tests")
struct PermissionsTests {

    @Test("OrgRole titles")
    func roleTitles() {
        #expect(OrgRole.owner.title == "Owner")
        #expect(OrgRole.manager.title == "Manager")
        #expect(OrgRole.cashier.title == "Cashier")
        #expect(OrgRole.accountant.title == "Accountant")
    }

    @Test("Super admin maps to owner")
    func superAdminMapsToOwner() {
        #expect(OrgRole(appRole: .superAdmin) == .owner)
    }

    @Test("Every permission has a non-empty title")
    func permissionTitles() {
        for permission in Permission.allCases {
            #expect(!permission.title.isEmpty)
        }
        #expect(Permission.createBill.title == "Create bill")
        #expect(Permission.undoOwnBill.title == "Undo own bill (5 min)")
        #expect(Permission.purchases.title == "Purchases & supplier payments")
        #expect(Permission.admin.title == "Admin section")
    }

    @Test("Owner is allowed everything and locked everywhere")
    func ownerLocked() {
        let empty = PermissionMatrix(grants: [:])
        for permission in Permission.allCases {
            #expect(empty.allows(permission, for: .owner))
            #expect(PermissionMatrix.isLocked(permission, for: .owner))
        }
    }

    @Test("Lock rules for admin and cashier billing")
    func lockRules() {
        #expect(PermissionMatrix.isLocked(.admin, for: .accountant))
        #expect(PermissionMatrix.isLocked(.createBill, for: .cashier))
        #expect(!PermissionMatrix.isLocked(.createBill, for: .manager))
        #expect(!PermissionMatrix.isLocked(.cancelBill, for: .cashier))
    }

    @Test("Role with no stored grants is denied unlocked permissions")
    func missingGrants() {
        let matrix = PermissionMatrix(grants: [:])
        #expect(!matrix.allows(.cancelBill, for: .manager))
        #expect(!matrix.allows(.viewInsights, for: .accountant))
        #expect(matrix.allows(.createBill, for: .cashier))
    }

    @Test("Turning a permission off removes it, and grants stay sorted")
    func setOffAndSorted() {
        var matrix = PermissionMatrix.standard
        #expect(matrix.allows(.returns, for: .cashier))
        matrix.set(.returns, for: .cashier, to: false)
        #expect(!matrix.allows(.returns, for: .cashier))

        matrix.set(.paySalary, for: .accountant, to: true)
        matrix.set(.expenses, for: .accountant, to: true)
        let list = matrix.grants[OrgRole.accountant.rawValue] ?? []
        #expect(list == list.sorted())
        #expect(list.contains(Permission.paySalary.rawValue))
    }

    @Test("Setting a permission for a role with no entry creates one")
    func setCreatesEntry() {
        var matrix = PermissionMatrix(grants: [:])
        matrix.set(.expenses, for: .manager, to: true)
        #expect(matrix.allows(.expenses, for: .manager))
    }

    @Test("Setting an owner permission is ignored")
    func ownerSetIgnored() {
        var matrix = PermissionMatrix(grants: [:])
        matrix.set(.cancelBill, for: .owner, to: false)
        #expect(matrix.grants[OrgRole.owner.rawValue] == nil)
        #expect(matrix.allows(.cancelBill, for: .owner))
    }

    @Test("Matrix round-trips through Codable")
    func codable() throws {
        let matrix = PermissionMatrix.standard
        let decoded = try JSONDecoder().decode(PermissionMatrix.self, from: JSONEncoder().encode(matrix))
        #expect(decoded == matrix)
    }
}
