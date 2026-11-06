//
//  AccountTests.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name

@Suite("Account Model Tests")
struct AccountTests {

    @Test("Standard initializer sets default values correctly")
    func testStandardInitialization() {
        let account = Account(name: "Main Bank", type: .bank, currentBalance: 1250.50)
        
        #expect(!account.id.isEmpty) // Should auto-generate UUID
        #expect(account.name == "Main Bank")
        #expect(account.type == .bank)
        #expect(account.currentBalance == 1250.50)
        #expect(account.isDeleted == false) // Default value
        #expect(account.updatedAt.timeIntervalSinceNow > -2.0) // Should be practically now
    }
    
    @Test("Custom decoder handles complete JSON data")
    func testFullJSONDecoding() throws {
        let jsonString = """
        {
            "id": "acc-12345",
            "name": "Cash Drawer",
            "type": "cash",
            "currentBalance": 500.0,
            "updatedAt": 1792866600,
            "isDeleted": true
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let account = try decoder.decode(Account.self, from: data)
        
        #expect(account.id == "acc-12345")
        #expect(account.name == "Cash Drawer")
        #expect(account.type == .cash)
        #expect(account.currentBalance == 500.0)
        #expect(account.isDeleted == true)
    }

    @Test("Custom decoder applies fallbacks for missing optional fields")
    func testPartialJSONDecodingFallbacks() throws {
        // Missing id, updatedAt, and isDeleted fields to trigger fallback logic
        let jsonString = """
        {
            "name": "UPI Wallet",
            "type": "upi",
            "currentBalance": 150.75
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        let account = try JSONDecoder().decode(Account.self, from: data)
        
        #expect(!account.id.isEmpty) // Fallback generated a new UUID
        #expect(account.name == "UPI Wallet")
        #expect(account.type == .upi)
        #expect(account.currentBalance == 150.75)
        #expect(account.isDeleted == false) // Fallback applied false
        #expect(account.updatedAt.timeIntervalSinceNow > -2.0) // Fallback generated current Date
    }
    
    @Test("Account encodes to valid JSON")
    func testEncodingRoundTrip() throws {
        let originalAccount = Account(
            id: "test-encode-id",
            name: "Shop Account",
            type: .bank,
            currentBalance: 1000.0,
            isDeleted: false
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalAccount)
        
        let decoder = JSONDecoder()
        let decodedAccount = try decoder.decode(Account.self, from: data)
        
        #expect(decodedAccount.id == originalAccount.id)
        #expect(decodedAccount.name == originalAccount.name)
        #expect(decodedAccount.type == originalAccount.type)
        #expect(decodedAccount.currentBalance == originalAccount.currentBalance)
        #expect(decodedAccount.isDeleted == originalAccount.isDeleted)
    }
}
