//
//  PosCartTests.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name

@Suite("PosCart Model Tests")
struct PosCartTests {

    // MARK: - PaymentMode Tests

    @Test("PaymentMode string raw values are correctly mapped")
    func testPaymentModeRawValues() {
        #expect(PaymentMode.cash.rawValue == "cash")
        #expect(PaymentMode.upi.rawValue == "upi")
        #expect(PaymentMode.card.rawValue == "card")
        #expect(PaymentMode.credit.rawValue == "credit")
    }

    // MARK: - PosCart Computed Properties Tests

    @Test("Empty cart returns zero for all calculated totals")
    func testEmptyCartTotals() {
        let cart = PosCart()
        
        #expect(cart.totalMRP == 0.0)
        #expect(cart.totalFinalPrice == 0.0)
        #expect(cart.totalDiscountOnMRP == 0.0)
        #expect(cart.totalItemsCount == 0)
        #expect(cart.totalPayable == 0.0)
        #expect(cart.paymentMode == .cash) // Default value check
    }

    @Test("Cart totals are calculated correctly with multiple items")
    func testCartTotalsWithItems() {
        // Adjust the CartItem initializer based on your actual CartItem definition
        let category = InventoryItem(name: "Gold Ring") // Using the InventoryItem model from previous context

        let item1 = CartItem(
            category: category,
            mrp: 100.0,
            discountPercent: 15.0,
            quantity: 2
        )
        
        let item2 = CartItem(category: category,
                             mrp: 500.0,
                             discountPercent: 15.0,
                             quantity: 1
        ) // MRP total: 500, Final: 400
        
        var cart = PosCart()
        cart.items = [item1, item2]
        cart.flatDiscount = 30.0
        
        #expect(cart.totalItemsCount == 3)
        #expect(cart.totalMRP == 700.0) // 200 + 500
        #expect(cart.totalFinalPrice == 595) // 180 + 400
        #expect(cart.totalDiscountOnMRP == 105) // 700 - 580
        #expect(cart.totalPayable == 565) // 580 - 30 (flat discount)
    }

    @Test("totalPayable floors at zero when flat discount exceeds total price")
    func testTotalPayableFloor() {
        let category = InventoryItem(name: "Gold Ring")
        
        let item = CartItem(
            category: category,
            mrp: 100.0,
            discountPercent: 15.0,
            quantity: 1,
            discountType: .percentage
        )
        var cart = PosCart()
        cart.items = [item]
        
        // Set a flat discount greater than the final price
        cart.flatDiscount = 150.0
        
        #expect(cart.totalFinalPrice == 85)
        // Ensure max(totalFinalPrice - flatDiscount, 0.0) logic works
        #expect(cart.totalPayable == 0.0)
    }
    
    // MARK: - JSON Encoding/Decoding Tests
    
    @Test("PosCart encodes and decodes round-trip accurately")
    func testEncodingRoundTrip() throws {
        var originalCart = PosCart()
        originalCart.flatDiscount = 50.0
        originalCart.paymentMode = .upi
        originalCart.customerName = "John Doe"
        originalCart.customerPhone = "1234567890"
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalCart)
        
        let decoder = JSONDecoder()
        let decodedCart = try decoder.decode(PosCart.self, from: data)
        
        #expect(decodedCart.flatDiscount == originalCart.flatDiscount)
        #expect(decodedCart.paymentMode == originalCart.paymentMode)
        #expect(decodedCart.customerName == originalCart.customerName)
        #expect(decodedCart.customerPhone == originalCart.customerPhone)
    }
}
