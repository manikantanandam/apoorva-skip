//
//  CashflowCategoryTests.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name

@Suite("CashflowCategory Model Tests")
struct CashflowCategoryTests {

    @Test("Enum initializes correctly from explicit raw string values")
    func testRawValues() {
        #expect(CashflowCategory(rawValue: "Shop Setup") == .shopSetup)
        #expect(CashflowCategory(rawValue: "Sales Revenue") == .salesRevenue)
        #expect(CashflowCategory(rawValue: "Inventory") == .inventory)
        #expect(CashflowCategory(rawValue: "Internal Transfer") == .internalTransfer)
        #expect(CashflowCategory(rawValue: "Maintenance & Repairs") == .maintenanceAndRepairs)
        #expect(CashflowCategory(rawValue: "Miscellaneous") == .miscellaneous)
        #expect(CashflowCategory(rawValue: "Utilities") == .utilities)
        #expect(CashflowCategory(rawValue: "Unknown") == .unknown)
        
        #expect(CashflowCategory(rawValue: "Invalid") == nil)
    }
    
    @Test("CaseIterable contains all defined categories")
    func testAllCases() {
        let allCases = CashflowCategory.allCases
        #expect(allCases.count == 8)
        #expect(allCases.contains(.shopSetup))
        #expect(allCases.contains(.unknown))
    }
    
    @Test("CashflowCategory encodes and decodes to valid JSON")
    func testEncodingRoundTrip() throws {
        let originalCategory = CashflowCategory.salesRevenue
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalCategory)
        
        // Ensure it encodes to the exact raw string value
        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString == "\"Sales Revenue\"")
        
        let decoder = JSONDecoder()
        let decodedCategory = try decoder.decode(CashflowCategory.self, from: data)
        
        #expect(decodedCategory == originalCategory)
    }
}
