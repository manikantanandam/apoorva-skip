//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name

@Suite("CategoryAnalytics Model Tests")
struct CategoryAnalyticsTests {

    @Test("Standard initializer sets properties correctly")
    func testInitialization() {
        let analytics = CategoryAnalytics(
            categoryName: "Electronics",
            categoryId: "cat-123",
            totalQty: 42,
            totalRevenue: 1500.75
        )
        
        #expect(analytics.categoryName == "Electronics")
        #expect(analytics.categoryId == "cat-123")
        #expect(analytics.totalQty == 42)
        #expect(analytics.totalRevenue == 1500.75)
    }
    
    @Test("CategoryAnalytics encodes and decodes to valid JSON")
    func testEncodingRoundTrip() throws {
        let originalAnalytics = CategoryAnalytics(
            categoryName: "Apparel",
            categoryId: "cat-456",
            totalQty: 10,
            totalRevenue: 250.0
        )
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalAnalytics)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedAnalytics = try decoder.decode(CategoryAnalytics.self, from: data)
        
        #expect(decodedAnalytics.categoryName == originalAnalytics.categoryName)
        #expect(decodedAnalytics.categoryId == originalAnalytics.categoryId)
        #expect(decodedAnalytics.totalQty == originalAnalytics.totalQty)
        #expect(decodedAnalytics.totalRevenue == originalAnalytics.totalRevenue)
    }
}
