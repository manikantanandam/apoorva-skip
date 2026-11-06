//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name if different

@Suite("InternalTransfer Model Tests")
struct InternalTransferTests {

    @Test("Standard initializer sets default and provided values correctly")
    func testStandardInitialization() {
        let transferDate = Date(timeIntervalSince1970: 1700000000)
        let transfer = InternalTransfer(
            id: "tx-999",
            fromAccountId: "acc-1",
            toAccountId: "acc-2",
            amount: 500.0,
            transferType: "cashToBank",
            timestamp: transferDate
        )
        
        #expect(transfer.id == "tx-999")
        #expect(transfer.fromAccountId == "acc-1")
        #expect(transfer.toAccountId == "acc-2")
        #expect(transfer.amount == 500.0)
        #expect(transfer.transferType == "cashToBank")
        #expect(transfer.timestamp == transferDate)
        
        // Check default values applied by the initializer
        #expect(transfer.isDeleted == false)
        #expect(transfer.updatedAt.timeIntervalSinceNow > -2.0)
    }
    
    @Test("InternalTransfer encodes and decodes to valid JSON")
    func testEncodingRoundTrip() throws {
        let originalTransfer = InternalTransfer(
            id: "tx-123",
            fromAccountId: "acc-A",
            toAccountId: "acc-B",
            amount: 250.50,
            transferType: "upiToBank",
            timestamp: Date(),
            updatedAt: Date(),
            isDeleted: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalTransfer)
        
        let decoder = JSONDecoder()
        let decodedTransfer = try decoder.decode(InternalTransfer.self, from: data)
        
        #expect(decodedTransfer.id == originalTransfer.id)
        #expect(decodedTransfer.fromAccountId == originalTransfer.fromAccountId)
        #expect(decodedTransfer.toAccountId == originalTransfer.toAccountId)
        #expect(decodedTransfer.amount == originalTransfer.amount)
        #expect(decodedTransfer.transferType == originalTransfer.transferType)
        #expect(decodedTransfer.isDeleted == originalTransfer.isDeleted)
        #expect(decodedTransfer.timestamp == originalTransfer.timestamp)
        #expect(decodedTransfer.updatedAt == originalTransfer.updatedAt)
    }
}
