//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaUtilities

@Suite("String Extension Tests")
struct StringExtensionTests {

    // MARK: - BoolValue Property Tests
    
    @Test("Parse exact true/false strings to Bool")
    func testBoolValuePropertyValid() {
        #expect("true".boolValue == true)
        #expect("false".boolValue == false)
    }
    
    @Test("Return nil for invalid or differently cased boolean strings")
    func testBoolValuePropertyInvalid() {
        #expect("TRUE".boolValue == nil) // Extension uses exact case matching
        #expect("False".boolValue == nil)
        #expect("random".boolValue == nil)
        #expect("".boolValue == nil)
    }
    
    // MARK: - BoolValue Method with Default Tests
    
    @Test("Return parsed Bool when string is valid, ignoring default")
    func testBoolValueMethodValid() {
        #expect("true".boolValue(defaultValue: false) == true)
        #expect("false".boolValue(defaultValue: true) == false)
    }
    
    @Test("Return default value when string is invalid")
    func testBoolValueMethodFallback() {
        #expect("invalid".boolValue(defaultValue: true) == true)
        #expect("".boolValue(defaultValue: false) == false)
    }
    
    // MARK: - JSON Decoding Tests
    
    // A simple test model
    private struct MockUser: Codable, Equatable {
        let id: Int
        let name: String
    }
    
    @Test("Decode valid JSON string to Decodable type")
    func testDecodeJSONSuccess() throws {
        let jsonString = """
        {
            "id": 1,
            "name": "Manikanta"
        }
        """
        
        let user: MockUser? = jsonString.decodeJSON()
        
        let unwrappedUser = try #require(user)
        #expect(unwrappedUser.id == 1)
        #expect(unwrappedUser.name == "Manikanta")
    }
    
    @Test("Return nil for malformed JSON string")
    func testDecodeJSONMalformed() {
        let invalidJsonString = "{ id: 1, name: missingQuotes }" // Invalid JSON format
        let user: MockUser? = invalidJsonString.decodeJSON()
        
        #expect(user == nil)
    }
    
    @Test("Return nil for valid JSON that mismatches the target model")
    func testDecodeJSONTypeMismatch() {
        let jsonString = """
        {
            "someOtherKey": "value"
        }
        """
        // The JSON is structurally valid but missing required 'MockUser' keys
        let user: MockUser? = jsonString.decodeJSON()
        
        #expect(user == nil)
    }
}
