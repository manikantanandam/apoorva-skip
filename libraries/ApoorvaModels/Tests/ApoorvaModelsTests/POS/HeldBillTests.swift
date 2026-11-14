//
//  HeldBillTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("HeldBill Model Tests")
struct HeldBillTests {

    @Test("Init stores values and defaults")
    func initDefaults() {
        let bill = HeldBill(customerName: "Asha", customerPhone: "9", items: [], total: 120)
        #expect(!bill.id.isEmpty)
        #expect(bill.customerName == "Asha")
        #expect(bill.total == 120)
        #expect(bill.updatedAt == nil)
        #expect(!bill.isDeleted)
    }

    @Test("Decoding an empty object falls back to defaults")
    func decodeEmpty() throws {
        let bill = try JSONDecoder().decode(HeldBill.self, from: Data("{}".utf8))
        #expect(!bill.id.isEmpty)
        #expect(bill.customerName.isEmpty)
        #expect(bill.customerPhone.isEmpty)
        #expect(bill.items.isEmpty)
        #expect(bill.total == 0)
        #expect(bill.updatedAt == nil)
        #expect(!bill.isDeleted)
    }

    @Test("Decoding wrong-typed fields falls back instead of throwing")
    func decodeMalformed() throws {
        let json = #"{"id":"h1","customerName":42,"total":"x","isDeleted":true}"#
        let bill = try JSONDecoder().decode(HeldBill.self, from: Data(json.utf8))
        #expect(bill.id == "h1")
        #expect(bill.customerName.isEmpty)
        #expect(bill.total == 0)
        #expect(bill.isDeleted)
    }

    @Test("Round-trips through Codable")
    func roundTrip() throws {
        let bill = HeldBill(id: "h1", customerName: "Asha", customerPhone: "9", items: [], total: 50,
                            createdAt: Date(timeIntervalSince1970: 1_000))
        let decoded = try JSONDecoder().decode(HeldBill.self, from: JSONEncoder().encode(bill))
        #expect(decoded == bill)
        #expect(decoded.total == 50)
        #expect(decoded.customerPhone == "9")
    }

    @Test("Equality uses id and ordering uses createdAt")
    func comparable() {
        let older = HeldBill(id: "a", customerName: "A", customerPhone: "", items: [], total: 1,
                             createdAt: Date(timeIntervalSince1970: 100))
        let newer = HeldBill(id: "b", customerName: "B", customerPhone: "", items: [], total: 2,
                             createdAt: Date(timeIntervalSince1970: 200))
        let sameIdAsOlder = HeldBill(id: "a", customerName: "Z", customerPhone: "", items: [], total: 9,
                                     createdAt: Date(timeIntervalSince1970: 300))
        #expect(older < newer)
        #expect(older == sameIdAsOlder)
        #expect([newer, older].sorted().first == older)
    }
}
