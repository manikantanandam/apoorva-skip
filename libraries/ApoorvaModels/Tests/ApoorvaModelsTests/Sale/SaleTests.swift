//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name

@Suite("Sale Model Tests")
struct SaleTests {

    // MARK: - Initialization Tests
    
    @Test("Standard initializer sets properties correctly")
    func testStandardInitialization() {
        let date = Date(timeIntervalSince1970: 1700000000)
        
        let sale = Sale(
            id: "sale-123",
            staffId: "staff-1",
            customerPhone: "9876543210",
            customerName: "Jane Doe",
            items: [],
            subtotal: 500.0,
            overallDiscountPercent: 10.0,
            overallDiscountAmount: 50.0,
            roundOff: 0.0,
            netPayable: 450.0,
            payments: [.cash: 450.0],
            timestamp: date,
            source: "iOS",
            status: "Completed",
            whatsappStatus: "sent",
            updatedAt: date,
            isDeleted: false
        )
        
        #expect(sale.id == "sale-123")
        #expect(sale.customerName == "Jane Doe")
        #expect(sale.netPayable == 450.0)
        #expect(sale.payments[.cash] == 450.0)
        #expect(sale.timestamp == date)
    }

    // MARK: - Decoding Tests
    
    @Test("Custom decoder handles complete JSON data correctly")
    func testFullJSONDecoding() throws {
        let jsonString = """
        {
            "id": "sale-456",
            "staffId": "staff-2",
            "customerPhone": "1234567890",
            "customerName": "John Smith",
            "items": [
                {
                    "cat_id": "cat-1",
                    "categoryName": "Rings",
                    "qty": 2,
                    "stickerPrice": 1000.0,
                    "finalPrice": 900.0,
                    "discountType": "amount"
                }
            ],
            "subtotal": 1800.0,
            "overallDiscountPercent": 0.0,
            "overallDiscountAmount": 0.0,
            "roundOff": 0.5,
            "netPayable": 1800.5,
            "payments": {
                "upi": 1800.5
            },
            "timestamp": 1700000000,
            "source": "Android",
            "status": "Completed",
            "whatsappStatus": "sent",
            "updatedAt": 1700005000,
            "isDeleted": false
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let sale = try decoder.decode(Sale.self, from: data)
        
        #expect(sale.id == "sale-456")
        #expect(sale.staffId == "staff-2")
        #expect(sale.items.count == 1)
        #expect(sale.items.first?.categoryName == "Rings")
        #expect(sale.timestamp.timeIntervalSince1970 == 1700000000)
    }
    
    @Test("Custom decoder applies bulletproof fallbacks for missing optional fields")
    func testPartialJSONDecodingFallbacks() throws {
        let jsonString = "{}" // Empty JSON object to force all fallbacks
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        let sale = try decoder.decode(Sale.self, from: data)
        
        // String Fallbacks
        #expect(sale.id == "")
        #expect(sale.staffId == "Unknown")
        #expect(sale.customerPhone == "")
        #expect(sale.customerName == "Walk-in")
        #expect(sale.source == "Unknown")
        #expect(sale.status == "Completed")
        #expect(sale.whatsappStatus == "unsent")
        
        // Number Fallbacks
        #expect(sale.subtotal == 0.0)
        #expect(sale.overallDiscountPercent == 0.0)
        #expect(sale.overallDiscountAmount == 0.0)
        #expect(sale.roundOff == 0.0)
        #expect(sale.netPayable == 0.0)
        
        // Collection Fallbacks
        #expect(sale.items.isEmpty)
        #expect(sale.payments.isEmpty)
        
        // Date & Bool Fallbacks
        #expect(sale.timestamp.timeIntervalSinceNow > -2.0)
        #expect(sale.updatedAt?.timeIntervalSinceNow ?? -1.0 > -2.0)
        #expect(sale.isDeleted == false)
    }

    // MARK: - Computed Properties Tests
    
    @Test("Computed math properties calculate correctly based on SaleItems")
    func testComputedMathProperties() throws {
        let jsonString = """
        {
            "items": [
                { "qty": 2, "stickerPrice": 100.0, "finalPrice": 90.0 },
                { "qty": 1, "stickerPrice": 200.0, "finalPrice": 200.0 }
            ],
            "overallDiscountAmount": 30.0,
            "roundOff": 5.0
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        let sale = try JSONDecoder().decode(Sale.self, from: data)
        
        // totalMRP = (100 * 2) + (200 * 1) = 400.0
        #expect(sale.totalMRP == 400.0)
        
        // Item 1 Unit Discount = 10.0 (x2 qty = 20.0). Item 2 Unit Discount = 0.0. Total = 20.0
        #expect(sale.totalItemsDiscount == 20.0)
        
        // subTotal = 400.0 - 20.0 = 380.0
        #expect(sale.subTotal == 380.0)
        
        // billAmount = 380.0 - 30.0 = 350.0
        #expect(sale.billAmount == 350.0)
        
        // totalSavings = 20.0 (items) + 30.0 (overall) + 5.0 (roundOff) = 55.0
        #expect(sale.totalSavings == 55.0)
    }

    // MARK: - Comparable Tests
    
    @Test("Sale equality is determined strictly by id")
    func testEquality() {
        let date = Date()
        let sale1 = Sale(id: "tx-1", staffId: "", customerPhone: "", customerName: "", items: [], subtotal: 0, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 0, payments: [:], timestamp: date, source: "", status: "", whatsappStatus: "")
        let sale2 = Sale(id: "tx-1", staffId: "diff", customerPhone: "diff", customerName: "diff", items: [], subtotal: 100, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 0, payments: [:], timestamp: date.addingTimeInterval(100), source: "", status: "", whatsappStatus: "")
        let sale3 = Sale(id: "tx-2", staffId: "", customerPhone: "", customerName: "", items: [], subtotal: 0, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 0, payments: [:], timestamp: date, source: "", status: "", whatsappStatus: "")
        
        #expect(sale1 == sale2)
        #expect(sale1 != sale3)
    }
    
    @Test("Sale magnitude comparison is determined by timestamp")
    func testComparable() {
        let past = Date(timeIntervalSince1970: 1000)
        let present = Date(timeIntervalSince1970: 2000)
        
        let olderSale = Sale(id: "1", staffId: "", customerPhone: "", customerName: "", items: [], subtotal: 0, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 0, payments: [:], timestamp: past, source: "", status: "", whatsappStatus: "")
        let newerSale = Sale(id: "2", staffId: "", customerPhone: "", customerName: "", items: [], subtotal: 0, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 0, payments: [:], timestamp: present, source: "", status: "", whatsappStatus: "")
        
        #expect(olderSale < newerSale)
        #expect(newerSale > olderSale)
    }
}
