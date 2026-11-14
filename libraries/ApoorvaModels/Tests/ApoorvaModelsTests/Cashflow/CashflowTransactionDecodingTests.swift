//
//  CashflowTransactionDecodingTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("CashflowTransaction Decoding & Ordering Tests")
struct CashflowTransactionDecodingTests {

    private func make(id: String = "t1", at seconds: TimeInterval = 100) -> CashflowTransaction {
        CashflowTransaction(id: id, timestamp: Date(timeIntervalSince1970: seconds), particulars: "Tea", amount: 20,
                            transactionType: .debit, paymentMode: .cash, category: .unknown,
                            fromAccountId: "a", toAccountId: "b", timestampInMs: seconds * 1000, updatedAtInMs: seconds * 1000)
    }

    @Test("Payment mode account ids")
    func accountIds() {
        #expect(CashflowTransaction.PaymentMode.cash.accountId == "b5ca46b1-8bb6-4c02-a42e-5d8507c04735")
        #expect(CashflowTransaction.PaymentMode.upi.accountId == "6b4b14b1-b8cb-4f7f-8881-91852e85b938")
        #expect(CashflowTransaction.PaymentMode.unknown.accountId.isEmpty)
    }

    @Test("Decoding with only required fields uses fallbacks")
    func decodeRequiredOnly() throws {
        let json = """
        {"id":"t1","timestamp":0,"particulars":"Tea","amount":20.5,"transactionType":"credit",
         "paymentMode":"upi","category":"not-a-category","isDeleted":false,"updatedAt":0}
        """
        let tx = try JSONDecoder().decode(CashflowTransaction.self, from: Data(json.utf8))
        #expect(tx.id == "t1")
        #expect(tx.amount == 20.5)
        #expect(tx.transactionType == .credit)
        #expect(tx.paymentMode == .upi)
        #expect(tx.category == .unknown)
        #expect(tx.subCategory == .unknown)
        #expect(tx.fromAccountId.isEmpty)
        #expect(tx.toAccountId.isEmpty)
        #expect(tx.person == nil)
        #expect(tx.timestampInMs == 0)
        #expect(tx.updatedAtInMs == 0)
    }

    @Test("Decoding keeps optional values when present")
    func decodeFull() throws {
        let json = """
        {"id":"t2","timestamp":0,"particulars":"Rent","amount":5000,"transactionType":"debit",
         "paymentMode":"cash","category":"unknown","subCategory":"unknown","fromAccountId":"a","toAccountId":"b",
         "person":"Ravi","isDeleted":true,"updatedAt":0,"timestampInMs":123,"updatedAtInMs":456}
        """
        let tx = try JSONDecoder().decode(CashflowTransaction.self, from: Data(json.utf8))
        #expect(tx.fromAccountId == "a")
        #expect(tx.toAccountId == "b")
        #expect(tx.person == "Ravi")
        #expect(tx.isDeleted)
        #expect(tx.timestampInMs == 123)
        #expect(tx.updatedAtInMs == 456)
    }

    @Test("Decoding fails when a required field is missing")
    func decodeMissingRequired() {
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(CashflowTransaction.self, from: Data(#"{"id":"x"}"#.utf8))
        }
    }

    @Test("Equality uses id, ordering uses timestamp")
    func comparable() {
        let early = make(id: "a", at: 100)
        let late = make(id: "b", at: 200)
        let sameIdAsEarly = make(id: "a", at: 999)
        #expect(early == sameIdAsEarly)
        #expect(early != late)
        #expect(early < late)
        #expect(late > early)
        #expect(!(early > late))
    }

    @Test("Encode then decode keeps id and amount")
    func roundTrip() throws {
        let tx = make()
        let decoded = try JSONDecoder().decode(CashflowTransaction.self, from: JSONEncoder().encode(tx))
        #expect(decoded.id == tx.id)
        #expect(decoded.amount == tx.amount)
        #expect(decoded.transactionType == .debit)
    }
}
