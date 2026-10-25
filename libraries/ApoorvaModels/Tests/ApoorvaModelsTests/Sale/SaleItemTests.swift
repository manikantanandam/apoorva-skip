//
//  SaleItemTests.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name

@Suite("SaleItem Model Tests")
struct SaleItemTests {

    // MARK: - Helper Methods
    
    /// Helper to instantiate SaleItem via JSON to avoid missing memberwise init errors
    private func createMockItem(json: String) throws -> SaleItem {
        let data = try #require(json.data(using: .utf8))
        return try JSONDecoder().decode(SaleItem.self, from: data)
    }

    // MARK: - Decoding Tests

    @Test("Custom decoder maps keys and handles complete JSON data correctly")
    func testFullJSONDecoding() throws {
        // Notice the use of "cat_id" to test the custom CodingKey mapping
        let jsonString = """
        {
            "cat_id": "cat-123",
            "categoryName": "Rings",
            "qty": 2,
            "stickerPrice": 500.0,
            "finalPrice": 450.0,
            "discountType": "amount"
        }
        """
        
        let item = try createMockItem(json: jsonString)
        
        #expect(!item.id.isEmpty) // Verifies UUID generation
        #expect(item.categoryId == "cat-123") // Verifies custom key mapping
        #expect(item.categoryName == "Rings")
        #expect(item.qty == 2)
        #expect(item.stickerPrice == 500.0)
        #expect(item.finalPrice == 450.0)
        #expect(item.discountType == .amount)
    }

    @Test("Custom decoder applies fallback values for missing optional fields")
    func testPartialJSONDecodingFallbacks() throws {
        let jsonString = "{}" // Empty JSON to force all fallbacks
        
        let item = try createMockItem(json: jsonString)
        
        #expect(!item.id.isEmpty)
        #expect(item.categoryId == "")
        #expect(item.categoryName == "")
        #expect(item.qty == 0)
        #expect(item.stickerPrice == 0.0)
        #expect(item.finalPrice == 0.0)
        #expect(item.discountType == .finalPrice)
    }

    // MARK: - Computed Properties Tests

    @Test("Computed properties calculate discounts and totals correctly")
    func testComputedProperties() throws {
        let jsonString = """
        {
            "qty": 3,
            "stickerPrice": 200.0,
            "finalPrice": 150.0
        }
        """
        let item = try createMockItem(json: jsonString)
        
        // discountPercent: ((200 - 150) / 200) * 100 = 25.0
        #expect(item.discountPercent == 25.0)
        
        // unitDiscountAmount: 200 - 150 = 50.0
        #expect(item.unitDiscountAmount == 50.0)
        
        // totalAmount: 3 * 150.0 = 450.0
        #expect(item.totalAmount == 450.0)
    }

    @Test("discountPercent returns 0.0 when stickerPrice is zero to prevent division by zero")
    func testDiscountPercentZeroStickerPrice() throws {
        let jsonString = """
        {
            "stickerPrice": 0.0,
            "finalPrice": 0.0
        }
        """
        let item = try createMockItem(json: jsonString)
        
        #expect(item.discountPercent == 0.0)
    }
}
