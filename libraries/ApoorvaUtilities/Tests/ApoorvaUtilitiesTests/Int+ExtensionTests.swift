//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Foundation
import Testing

@Suite("Int Extension Tests")
struct IntExtensionTests {
    @Test("Test String Conversion")
    func testStringConversion() {
        let intValue = 1
        
        #expect(intValue.string == "1")
    }
    
    @Test("Test Int64 Conversion")
    func testInteger64Conversion() {
        let intValue = 1
        
        #expect(intValue.int64Value == 1)
    }
    
    @Test("Test Date Conversion")
    func testDateConversion() {
        let timestamp: Int = 1792866600
        let date = timestamp.date
        let dateResult = Date.from(day: 25, month: 10, year: 2026)
        #expect(date == dateResult)
        
    }
}
