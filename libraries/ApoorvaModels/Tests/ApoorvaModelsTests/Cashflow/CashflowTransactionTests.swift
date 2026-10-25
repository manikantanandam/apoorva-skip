//
//  CashflowTransactionTests.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name

@Suite("CashflowTransaction Model Tests")
struct CashflowTransactionTests {

    // MARK: - Payment Mode Tests
    
    @Test("PaymentMode returns correct predefined account IDs")
    func testPaymentModeAccountIds() {
        #expect(CashflowTransaction.PaymentMode.cash.accountId == "b5ca46b1-8bb6-4c02-a42e-5d8507c04735")
        #expect(CashflowTransaction.PaymentMode.upi.accountId == "6b4b14b1-b8cb-4f7f-8881-91852e85b938")
        #expect(CashflowTransaction.PaymentMode.unknown.accountId == "")
    }

    // MARK: - Custom Decoding Tests
    
    @Test("Custom decoder handles complete JSON data correctly")
    func testFullJSONDecoding() throws {
        // Note: Replace "sales" and "retail" with valid JSON representations for your CashflowCategory/CashflowSubCategory types
        let jsonString = """
        {
            "id": "tx-full-123",
            "timestamp": 1700000000,
            "particulars": "Daily Sales",
            "amount": 500.0,
            "transactionType": "credit",
            "paymentMode": "cash",
            "category": "sales",
            "subCategory": "retail",
            "fromAccountId": "acc-from",
            "toAccountId": "acc-to",
            "person": "John Doe",
            "isDeleted": false,
            "updatedAt": 1700000000,
            "timestampInMs": 1700000000000,
            "updatedAtInMs": 1700000000000
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        let transaction = try decoder.decode(CashflowTransaction.self, from: data)
        #expect(transaction.id == "tx-full-123")
        #expect(transaction.particulars == "Daily Sales")
        #expect(transaction.amount == 500.0)
        #expect(transaction.transactionType == .credit)
        #expect(transaction.paymentMode == .cash)
        #expect(transaction.fromAccountId == "acc-from")
        #expect(transaction.toAccountId == "acc-to")
        #expect(transaction.person == "John Doe")
        #expect(transaction.isDeleted == false)
        #expect(transaction.timestampInMs == 1700000000000)
    }

    @Test("Custom decoder applies fallbacks for missing optional fields")
    func testPartialJSONDecodingFallbacks() throws {
        let jsonString = """
        {
            "id": "tx-partial-123",
            "timestamp": 1700000000,
            "particulars": "Miscellaneous",
            "amount": 100.0,
            "transactionType": "debit",
            "paymentMode": "upi",
            "category": "expense",
            "isDeleted": false,
            "updatedAt": 1700000000
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let transaction = try decoder.decode(CashflowTransaction.self, from: data)
        
        // Check standard fields
        #expect(transaction.id == "tx-partial-123")
        #expect(transaction.subCategory == .unknown)
        #expect(transaction.person == nil)
        
        // Check fallbacks defined in the custom init(from decoder:)
        #expect(transaction.fromAccountId == "")
        #expect(transaction.toAccountId == "")
        #expect(transaction.timestampInMs == 0)
        #expect(transaction.updatedAtInMs == 0)
    }
    
    // MARK: - Comparable & Equatable Tests
    
    @Test("CashflowTransaction equality is based solely on id")
    func testEquality() throws {
        // Decode a mock transaction
        let jsonString = """
        {
            "id": "tx-same-id",
            "timestamp": 1700000000,
            "particulars": "Item A",
            "amount": 10.0,
            "transactionType": "credit",
            "paymentMode": "cash",
            "category": "sales",
            "isDeleted": false,
            "updatedAt": 1700000000
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        var transaction1 = try decoder.decode(CashflowTransaction.self, from: data)
        var transaction2 = transaction1
        
        // Change properties on the second transaction but keep the ID the same
        transaction2.amount = 999.9
        transaction2.particulars = "Item B"
        
        // Should be equal because the ID matches
        #expect(transaction1 == transaction2)
        
        // Change ID
        transaction2.id = "tx-different-id"
        #expect(transaction1 != transaction2)
    }
    
    @Test("CashflowTransaction comparison is based on timestamp")
    func testComparable() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        let olderData = try #require("""
        { "id": "tx-old", "timestamp": 1000000000, "particulars": "", "amount": 0, "transactionType": "unknown", "paymentMode": "unknown", "category": "unknown", "isDeleted": false, "updatedAt": 1000000000 }
        """.data(using: .utf8))
        
        let newerData = try #require("""
        { "id": "tx-new", "timestamp": 2000000000, "particulars": "", "amount": 0, "transactionType": "unknown", "paymentMode": "unknown", "category": "unknown", "isDeleted": false, "updatedAt": 2000000000 }
        """.data(using: .utf8))
        
        let olderTransaction = try decoder.decode(CashflowTransaction.self, from: olderData)
        let newerTransaction = try decoder.decode(CashflowTransaction.self, from: newerData)
        
        #expect(olderTransaction < newerTransaction)
        #expect(newerTransaction > olderTransaction)
    }
}
