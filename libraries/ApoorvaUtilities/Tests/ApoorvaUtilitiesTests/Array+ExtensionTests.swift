//
//  ArrayExtensionTests.swift
//  ApoorvaUtilitiesTests
//

import Testing
import Foundation
@testable import ApoorvaUtilities // Imports the module containing your extension

@Suite("Array+Extension JSON String Tests")
struct ArrayExtensionTests {

    @Test("It should return '[]' for an empty array")
    func testEmptyArrayString() {
        let emptyArray: [String] = []
        #expect(emptyArray.string == "[]")
    }

    @Test("It should correctly encode an array of integers")
    func testIntegerArrayString() {
        let intArray = [1, 2, 3]
        #expect(intArray.string == "[1,2,3]")
    }

    @Test("It should correctly encode an array of strings")
    func testStringArrayString() {
        let stringArray = ["apple", "banana"]
        #expect(stringArray.string == "[\"apple\",\"banana\"]")
    }

    @Test("It should correctly encode an array of custom Encodable models")
    func testCustomEncodableArrayString() {
        // Define a simple custom encodable type for testing
        struct MockUser: Encodable {
            let id: Int
            let name: String
        }
        
        let customArray = [MockUser(id: 1, name: "Nani")]
        
        // JSONEncoder encodes without spaces by default
        let expectedJSONString = "[{\"id\":1,\"name\":\"Nani\"}]"
        
        #expect(customArray.string == expectedJSONString)
    }
}
