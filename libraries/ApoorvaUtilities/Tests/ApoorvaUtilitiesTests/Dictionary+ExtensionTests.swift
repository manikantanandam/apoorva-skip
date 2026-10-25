//
//  Dictionary+ExtensionTests.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaUtilities

@Suite("Dictionary Extension Tests")
struct DictionaryExtensionTests {

    @Test("Encode valid dictionary to JSON string")
    func testValidDictionaryEncoding() {
        let dict: [String: String] = ["name": "Manikanta", "role": "iOS Engineer"]
        
        let jsonString = dict.string
        
        // JSON serialization doesn't guarantee key order, so we check for substring presence
        #expect(jsonString.contains("\"name\":\"Manikanta\""))
        #expect(jsonString.contains("\"role\":\"iOS Engineer\""))
        #expect(jsonString.hasPrefix("{") && jsonString.hasSuffix("}"))
    }
    
    @Test("Encode empty dictionary")
    func testEmptyDictionary() {
        let emptyDict: [String: Int] = [:]
        
        #expect(emptyDict.string == "{}")
    }
    
    @Test("Fallback to empty braces on encoding failure")
    func testEncodingFailureFallback() {
        // Double.infinity cannot be represented in standard JSON and will cause JSONEncoder to throw,
        // which triggers your fallback logic to return "{}"
        let invalidDict: [String: Double] = ["invalid": .infinity]
        
        #expect(invalidDict.string == "{}")
    }
}
