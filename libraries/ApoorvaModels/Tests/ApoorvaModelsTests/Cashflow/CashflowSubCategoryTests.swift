//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name

@Suite("CashflowSubCategory Model Tests")
struct CashflowSubCategoryTests {

    @Test("Enum initializes correctly from explicit raw string values")
    func testRawValues() {
        #expect(CashflowSubCategory(rawValue: "Painting") == .painting)
        #expect(CashflowSubCategory(rawValue: "Woodwork") == .woodwork)
        #expect(CashflowSubCategory(rawValue: "Ready Stock") == .readyStock)
        #expect(CashflowSubCategory(rawValue: "Pooja/Festival") == .poojaFestival)
        #expect(CashflowSubCategory(rawValue: "Phone/Recharge") == .phoneRecharge)
        #expect(CashflowSubCategory(rawValue: "Unknown") == .unknown)
        
        #expect(CashflowSubCategory(rawValue: "Invalid") == nil)
    }
    
    @Test("CaseIterable contains all defined sub-categories")
    func testAllCases() {
        let allCases = CashflowSubCategory.allCases
        
        // Verifies the exact count of all cases defined in the enum
        #expect(allCases.count == 24)
        
        #expect(allCases.contains(.painting))
        #expect(allCases.contains(.ceiling))
        #expect(allCases.contains(.unknown))
    }
    
    @Test("CashflowSubCategory encodes and decodes to valid JSON")
    func testEncodingRoundTrip() throws {
        let originalCategory = CashflowSubCategory.poojaFestival
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalCategory)
        
        // Ensure it encodes to the exact raw string value wrapped in JSON quotes
        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString == "\"Pooja\\/Festival\"")
        
        let decoder = JSONDecoder()
        let decodedCategory = try decoder.decode(CashflowSubCategory.self, from: data)
        
        #expect(decodedCategory == originalCategory)
    }
}
