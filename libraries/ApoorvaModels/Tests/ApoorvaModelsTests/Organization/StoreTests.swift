//
//  StoreTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("Store Model Tests")
struct StoreTests {

    @Test("Init defaults")
    func initDefaults() {
        let store = Store(name: "Main", vertical: .kirana)
        #expect(Store.collection == "stores")
        #expect(!store.id.isEmpty)
        #expect(store.address.isEmpty)
        #expect(store.phone.isEmpty)
        #expect(store.billPrefix.isEmpty)
        #expect(store.accent == nil)
        #expect(store.isLive)
        #expect(store.updatedAt == nil)
        #expect(!store.isDeleted)
    }

    @Test("Default store uses the default id and bill prefix")
    func defaultStore() {
        let store = Store.defaultStore(name: "Shop", vertical: .parlour)
        #expect(store.id == Store.defaultId)
        #expect(store.billPrefix == "A-")
        #expect(store.vertical == .parlour)
        #expect(Store.defaultStore(name: "Shop", vertical: .fancy, billPrefix: "F-").billPrefix == "F-")
    }

    @Test("Store round-trips through Codable")
    func storeCodable() throws {
        let store = Store(id: "s1", name: "Main", vertical: .jewellery, accent: .brass,
                          createdAt: Date(timeIntervalSince1970: 1_000))
        let decoded = try JSONDecoder().decode(Store.self, from: JSONEncoder().encode(store))
        #expect(decoded == store)
        #expect(decoded.accent == .brass)
    }

    @Test("Member init defaults")
    func memberDefaults() {
        let member = Member(id: "u1", name: "Ravi", role: .cashier)
        #expect(Member.collection == "members")
        #expect(member.storeIds == [Store.defaultId])
        #expect(member.isActive)
        #expect(member.status == "active")
        #expect(member.commissionPercent == nil)
        #expect(member.baseSalary == nil)
        #expect(member.joinedAt != nil)
    }

    @Test("Member decoding fills defaults for missing fields")
    func memberDecodeDefaults() throws {
        let member = try JSONDecoder().decode(Member.self, from: Data(#"{"role":"manager"}"#.utf8))
        #expect(member.id.isEmpty)
        #expect(member.name.isEmpty)
        #expect(member.phone.isEmpty)
        #expect(member.email.isEmpty)
        #expect(member.role == .manager)
        #expect(member.storeIds == [Store.defaultId])
        #expect(member.isActive)
        #expect(member.status == "active")
        #expect(member.commissionPercent == nil)
        #expect(member.baseSalary == nil)
        #expect(member.joinedAt == nil)
        #expect(member.updatedAt == nil)
        #expect(!member.isDeleted)
    }

    @Test("Member decoding keeps provided values")
    func memberDecodeValues() throws {
        let json = """
        {"id":"u1","name":"Ravi","phone":"9","email":"r@x.com","role":"accountant","storeIds":["a","b"],
         "isActive":false,"status":"invited","commissionPercent":5.5,"baseSalary":12000,"isDeleted":true}
        """
        let member = try JSONDecoder().decode(Member.self, from: Data(json.utf8))
        #expect(member.id == "u1")
        #expect(member.email == "r@x.com")
        #expect(member.storeIds == ["a", "b"])
        #expect(!member.isActive)
        #expect(member.status == "invited")
        #expect(member.commissionPercent == 5.5)
        #expect(member.baseSalary == 12000)
        #expect(member.isDeleted)
    }

    @Test("Member decoding fails without a role")
    func memberRequiresRole() {
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(Member.self, from: Data("{}".utf8))
        }
    }
}
