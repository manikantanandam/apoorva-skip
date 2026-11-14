//
//  CustomerExtraTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("Customer Extra Tests")
struct CustomerExtraTests {

    private func make(name: String = "Asha", phone: String = "9999", createdDaysAgo: Int = 0) -> Customer {
        let created = Calendar.current.date(byAdding: .day, value: -createdDaysAgo, to: Date())!
        return Customer(name: name, phone: phone, createdAt: created.timeIntervalSince1970, lastPurchaseDate: nil,
                        totalSales: 0, totalAmountSpent: 0, updatedAt: nil, isDeleted: false)
    }

    private func decode(_ json: String) throws -> Customer {
        try JSONDecoder().decode(Customer.self, from: Data(json.utf8))
    }

    @Test("Init defaults for optional fields")
    func initDefaults() {
        let customer = make()
        #expect(customer.id == "9999")
        #expect(customer.creditLimit == nil)
        #expect(customer.birthday == nil)
        #expect(customer.dueBalance == 0)
        #expect(customer.priceTier == nil)
        #expect(customer.notes == nil)
        #expect(customer.whatsappReceipts)
    }

    @Test("Decoding an empty object falls back to defaults")
    func decodeEmpty() throws {
        let customer = try decode("{}")
        #expect(customer.name.isEmpty)
        #expect(customer.phone.isEmpty)
        #expect(customer.createdAt == 0)
        #expect(customer.lastPurchaseDate == nil)
        #expect(customer.totalSales == 0)
        #expect(customer.totalAmountSpent == 0)
        #expect(customer.updatedAt == 0)
        #expect(!customer.isDeleted)
        #expect(customer.dueBalance == 0)
        #expect(customer.whatsappReceipts)
    }

    @Test("Phone falls back to the document id")
    func phoneFromDocumentId() throws {
        #expect(try decode(#"{"id":"8888"}"#).phone == "8888")
        #expect(try decode(#"{"id":"8888","phone":"7777"}"#).phone == "7777")
    }

    @Test("Round-trip preserves all fields")
    func roundTrip() throws {
        var customer = make(name: "Ravi", phone: "1234")
        customer.lastPurchaseDate = 1_000
        customer.updatedAt = 2_000
        customer.creditLimit = 500
        customer.birthday = 3_000
        customer.dueBalance = 75
        customer.priceTier = "gold"
        customer.notes = "VIP"
        customer.whatsappReceipts = false
        customer.totalSales = 4
        customer.totalAmountSpent = 900

        let decoded = try JSONDecoder().decode(Customer.self, from: JSONEncoder().encode(customer))
        #expect(decoded.name == "Ravi")
        #expect(decoded.phone == "1234")
        #expect(decoded.lastPurchaseDate == 1_000)
        #expect(decoded.updatedAt == 2_000)
        #expect(decoded.creditLimit == 500)
        #expect(decoded.birthday == 3_000)
        #expect(decoded.dueBalance == 75)
        #expect(decoded.priceTier == "gold")
        #expect(decoded.notes == "VIP")
        #expect(!decoded.whatsappReceipts)
        #expect(decoded.totalSales == 4)
        #expect(decoded.totalAmountSpent == 900)
    }

    @Test("Tenure wording by age")
    func tenure() {
        #expect(make(createdDaysAgo: 0).tenure == "Joined Today")
        #expect(make(createdDaysAgo: 5).tenure == "Customer for 5 days")
        #expect(make(createdDaysAgo: 30).tenure == "Customer for 1 month")
        #expect(make(createdDaysAgo: 90).tenure == "Customer for 3 months")
        #expect(make(createdDaysAgo: 365).tenure == "Customer for 1 year")
        #expect(make(createdDaysAgo: 365 * 2 + 65).tenure == "Customer for 2 years, 2 months")
    }

    @Test("Customers order by name")
    func comparable() {
        #expect(make(name: "Amit") < make(name: "Zoya"))
        #expect([make(name: "B"), make(name: "A")].sorted().first?.name == "A")
    }

    @Test("VCF export")
    func vcf() {
        let vcf = [make(name: "Asha", phone: "111")].vcfString
        #expect(vcf.contains("BEGIN:VCARD"))
        #expect(vcf.contains("FN:Asha Apoorva Customer"))
        #expect(vcf.contains("TEL;TYPE=CELL:111"))
        #expect(vcf.contains("END:VCARD"))
        #expect([Customer]().vcfString.isEmpty)
    }

    @Test("CSV export quotes names containing commas")
    func csv() {
        let csv = [make(name: "Asha", phone: "111"), make(name: "Rao, K", phone: "222")].csvString
        #expect(csv.hasPrefix("Name,Phone\n"))
        #expect(csv.contains("Asha,111\n"))
        #expect(csv.contains("\"Rao, K Apoorva Customer\",222\n"))
        #expect([Customer]().csvString == "Name,Phone\n")
    }
}
