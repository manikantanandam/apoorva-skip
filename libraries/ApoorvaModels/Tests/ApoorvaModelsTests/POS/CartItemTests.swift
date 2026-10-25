//
//  CartItemTests.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name

@Suite("CartItem Model Tests")
struct CartItemTests {

    // MARK: - DiscountType Tests
    
    @Test("DiscountType string raw values are correctly mapped")
    func testDiscountTypeRawValues() {
        #expect(DiscountType.percentage.rawValue == "percentage")
        #expect(DiscountType.amount.rawValue == "amount")
        #expect(DiscountType.finalPrice.rawValue == "finalPrice")
    }

    // MARK: - Computed Properties Tests

    @Test("Computed prices calculate and round correctly with discounts")
    func testComputedPrices() {
        let category = InventoryItem(name: "Gold Ring") // Using the InventoryItem model from previous context
        
        // 15% discount on 200.0 MRP = 170.0 final price
        let item = CartItem(
            category: category,
            mrp: 200.0,
            discountPercent: 15.0,
            quantity: 3,
            discountType: .percentage
        )
        
        #expect(item.finalPrice == 170.0)
        #expect(item.totalItemsPrice == 510.0) // 170.0 * 3
    }
    
    @Test("Computed prices round correctly for fractional values")
    func testComputedPricesRounding() {
        let category = InventoryItem(name: "Silver Chain")
        
        // 33% discount on 100.0 MRP = 67.0 (rounded from 67.0)
        // Let's test a value that forces rounding: 12.5% of 99.0 = 86.625 -> rounds to 87.0
        let item = CartItem(
            category: category,
            mrp: 99.0,
            discountPercent: 12.5,
            quantity: 1,
            discountType: .percentage
        )
        
        #expect(item.finalPrice == 87.0)
        #expect(item.totalItemsPrice == 87.0)
    }

    // MARK: - JSON Decoding Tests

    @Test("Custom decoder handles complete JSON data correctly")
    func testFullJSONDecoding() throws {
        let jsonString = """
        {
            "category": {
                "id": "item-1",
                "name": "Necklace",
                "currentStock": 5
            },
            "mrp": 1000.0,
            "discountPercent": 10.0,
            "quantity": 2,
            "discountType": "amount"
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        let cartItem = try decoder.decode(CartItem.self, from: data)
        
        #expect(cartItem.category.name == "Necklace")
        #expect(cartItem.mrp == 1000.0)
        #expect(cartItem.discountPercent == 10.0)
        #expect(cartItem.quantity == 2)
        #expect(cartItem.discountType == .amount)
    }

    @Test("Custom decoder applies fallbacks for missing discount fields")
    func testPartialJSONDecodingFallbacks() throws {
        let jsonString = """
        {
            "category": {
                "id": "item-2",
                "name": "Bangle",
                "currentStock": 10
            },
            "mrp": 500.0,
            "quantity": 4
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        let cartItem = try decoder.decode(CartItem.self, from: data)
        
        #expect(cartItem.category.name == "Bangle")
        #expect(cartItem.mrp == 500.0)
        #expect(cartItem.quantity == 4)
        
        // Verifies the fallbacks defined in init(from decoder:)
        #expect(cartItem.discountPercent == 0.0)
        #expect(cartItem.discountType == .percentage)
    }
}
