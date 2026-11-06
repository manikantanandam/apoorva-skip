//
//  CustomerTests.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name

@Suite("Customer Model Tests")
struct CustomerTests {
    
    // MARK: - Initialization Tests

    @Test("Standard initializer populates fields and generates ID")
    func testInitialization() {
        let customer = Customer(
            name: "Jane Doe",
            phone: "9876543210",
            createdAt: 1700000000,
            lastPurchaseDate: nil,
            totalSales: 5,
            totalAmountSpent: 1200.50,
            updatedAt: 1700000000,
            isDeleted: false
        )
        
        #expect(!customer.id.isEmpty) // UUID should be generated
        #expect(customer.name == "Jane Doe")
        #expect(customer.phone == "9876543210")
        #expect(customer.createdAt == 1700000000)
        #expect(customer.lastPurchaseDate == nil)
        #expect(customer.totalSales == 5)
        #expect(customer.totalAmountSpent == 1200.50)
        #expect(customer.updatedAt == 1700000000)
        #expect(customer.isDeleted == false)
    }

    // MARK: - Decoding Tests

    @Test("Custom decoder handles complete JSON data")
    func testFullJSONDecoding() throws {
        let jsonString = """
        {
            "name": "John Smith",
            "phone": "1234567890",
            "createdAt": 1700000000,
            "lastPurchaseDate": 1700005000,
            "totalSales": 10,
            "totalAmountSpent": 5000.0,
            "updatedAt": 1700000000,
            "isDeleted": true
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let customer = try decoder.decode(Customer.self, from: data)
        
        #expect(!customer.id.isEmpty) // Decoder generates new UUID
        #expect(customer.name == "John Smith")
        #expect(customer.phone == "1234567890")
        #expect(customer.createdAt == 1700000000)
        #expect(customer.lastPurchaseDate == 1700005000)
        #expect(customer.totalSales == 10)
        #expect(customer.totalAmountSpent == 5000.0)
        #expect(customer.updatedAt == 1700000000)
        #expect(customer.isDeleted == true)
    }
    
    @Test("Custom decoder applies fallbacks for missing optional fields")
    func testPartialJSONDecodingFallbacks() throws {
        let jsonString = """
        {
            "name": "Alice Minimal",
            "phone": "5555555555"
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let customer = try decoder.decode(Customer.self, from: data)
        
        #expect(customer.name == "Alice Minimal")
        #expect(customer.createdAt == 0) // Fallback for missing createdAt
        #expect(customer.lastPurchaseDate == nil)
        #expect(customer.totalSales == 0)
        #expect(customer.totalAmountSpent == 0.0)
        #expect(customer.updatedAt == 0)
        #expect(customer.isDeleted == false)
    }

    // MARK: - Tenure Computed Property Tests

    @Test("Tenure calculates correctly for 'Joined Today'")
    func testTenureJoinedToday() {
        let now = Date().timeIntervalSince1970
        let customer = createMockCustomer(createdAt: now)
        #expect(customer.tenure == "Joined Today")
    }

    @Test("Tenure calculates correctly for days (< 30)")
    func testTenureDays() {
        let tenDaysAgo = Date().addingTimeInterval(-10 * 24 * 60 * 60).timeIntervalSince1970
        let customer = createMockCustomer(createdAt: tenDaysAgo)
        #expect(customer.tenure == "Customer for 10 days")
    }

    @Test("Tenure calculates correctly for months (< 365 days)")
    func testTenureMonths() {
        let fortyDaysAgo = Date().addingTimeInterval(-40 * 24 * 60 * 60).timeIntervalSince1970
        let customer = createMockCustomer(createdAt: fortyDaysAgo)
        #expect(customer.tenure == "Customer for 1 month") // 40 / 30 = 1
        
        let seventyDaysAgo = Date().addingTimeInterval(-70 * 24 * 60 * 60).timeIntervalSince1970
        let customer2 = createMockCustomer(createdAt: seventyDaysAgo)
        #expect(customer2.tenure == "Customer for 2 months") // 70 / 30 = 2
    }

    @Test("Tenure calculates correctly for years")
    func testTenureYears() {
        let oneYearAgo = Date().addingTimeInterval(-365 * 24 * 60 * 60).timeIntervalSince1970
        let customer = createMockCustomer(createdAt: oneYearAgo)
        #expect(customer.tenure == "Customer for 1 year")
        
        // 365 + 30 days = 395 days (1 year, 1 month)
        let oneYearOneMonthAgo = Date().addingTimeInterval(-395 * 24 * 60 * 60).timeIntervalSince1970
        let customer2 = createMockCustomer(createdAt: oneYearOneMonthAgo)
        #expect(customer2.tenure == "Customer for 1 year, 1 month")
        
        // 730 + 60 days = 790 days (2 years, 2 months)
        let twoYearsTwoMonthsAgo = Date().addingTimeInterval(-790 * 24 * 60 * 60).timeIntervalSince1970
        let customer3 = createMockCustomer(createdAt: twoYearsTwoMonthsAgo)
        #expect(customer3.tenure == "Customer for 2 years, 2 months")
    }

    // MARK: - Comparable Tests
    
    @Test("Customer comparable sorting by name")
    func testComparableSorting() {
        let charlie = createMockCustomer(name: "Charlie")
        let alice = createMockCustomer(name: "Alice")
        let bob = createMockCustomer(name: "Bob")
        
        let sorted = [charlie, alice, bob].sorted()
        
        #expect(sorted[0].name == "Alice")
        #expect(sorted[1].name == "Bob")
        #expect(sorted[2].name == "Charlie")
    }

    // MARK: - Array Extension Tests
    
    @Test("Array vcfString extension formats correctly")
    func testVcfString() {
        let customer = createMockCustomer(name: "John", phone: "12345")
        let vcf = [customer].vcfString
        
        let expectedOutput = """
        BEGIN:VCARD
        VERSION:3.0
        N:;John Apoorva Customer;;;
        FN:John Apoorva Customer
        TEL;TYPE=CELL:12345
        END:VCARD\n
        """
        
        #expect(vcf == expectedOutput)
    }

    @Test("Array csvString extension formats correctly and escapes commas")
    func testCsvString() {
        let normalCustomer = createMockCustomer(name: "John", phone: "111")
        let commaCustomer = createMockCustomer(name: "Doe, Jane", phone: "222")
        
        let csv = [normalCustomer, commaCustomer].csvString
        
        let expectedOutput = """
        Name,Phone
        John,111
        "Doe, Jane Apoorva Customer",222\n
        """
        
        #expect(csv == expectedOutput)
    }
    
    // MARK: - Helper Methods
    
    private func createMockCustomer(name: String = "Test", phone: String = "000", createdAt: TimeInterval = 0) -> Customer {
        return Customer(
            name: name,
            phone: phone,
            createdAt: createdAt,
            lastPurchaseDate: nil,
            totalSales: 0,
            totalAmountSpent: 0,
            updatedAt: nil,
            isDeleted: false
        )
    }
}
