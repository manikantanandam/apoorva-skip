//
//  BoolExtensionTests.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
@testable import ApoorvaUtilities

@Suite("Bool+Extension Test")
struct BoolExtensionTests {
    
    @Test("Checks String Value")
    func testStringValueConversion() {
        let trueValue = true
        #expect(trueValue.stringValue == "true")
        
        let falseValue = false
        #expect(falseValue.stringValue == "false")
    }
    
    @Test("Checks Integer Value")
    func testIntegerConversion() {
        let trueValue = true
        #expect(trueValue.intValue == 1)
        
        let falseValue = false
        #expect(falseValue.intValue == 0)
    }
    
    @Test("Checks Integer 64 Value")
    func testInteger64Conversion() {
        let trueValue = true
        #expect(trueValue.int64Value == 1)
        
        let falseValue = false
        #expect(falseValue.int64Value == 0)
    }
}
