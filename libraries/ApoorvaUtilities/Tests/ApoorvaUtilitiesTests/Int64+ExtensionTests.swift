//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Foundation
import Testing

@Suite("Int64 Extension Tests")
struct Int64ExtensionTests {
    @Test("Test String Conversion")
    func testStringConversion() {
        let intValue: Int64 = 1
        
        #expect(intValue.intValue == 1)
    }
    
    @Test("Test Bool Conversion")
    func testBoolConversion() {
        let one: Int64 = 1
        #expect(one.boolValue == true)
        
        let zero: Int64 = 0
        #expect(zero.boolValue == false)
        
        let two: Int64 = 2
        #expect(two.boolValue == false)
    }
    
    @Test("Test Optional Bool Conversion")
    func testOptionalBoolConversion() {
        let one: Int64 = 1
        #expect(one.optionalBoolValue == true)
        
        let zero: Int64 = 0
        #expect(zero.optionalBoolValue == false)
        
        let two: Int64 = 2
        #expect(two.optionalBoolValue == nil)
    }
    
    @Test("Test Date Conversion")
    func testDateConversion() throws {
        // Construct the expected date dynamically based on the runner's local calendar
        let dateResult = try #require(Date.from(day: 25, month: 10, year: 2026))
        
        // Derive the timestamp from the dynamically created date
        let timestamp: Int64 = Int64(dateResult.timeIntervalSince1970)
        
        let date = timestamp.date
        #expect(date == dateResult)
    }
}
