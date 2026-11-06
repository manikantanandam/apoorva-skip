//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name

@Suite("OrganizationSnapshot Model Tests")
struct OrganizationSnapshotTests {

    @Test("Custom decoder handles complete JSON data correctly")
    func testFullJSONDecoding() throws {
        let jsonString = """
        {
            "orgId": "org-789",
            "name": "Apoorva Jewellers",
            "accentColor": "#000000"
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        let snapshot = try decoder.decode(OrganizationSnapshot.self, from: data)
        
        // Check decoded properties
        #expect(snapshot.orgId == "org-789")
        #expect(snapshot.name == "Apoorva Jewellers")
        #expect(snapshot.accentColor == "#000000")
        
        // Check Identifiable computed property
        #expect(snapshot.id == "org-789")
    }

    @Test("Custom decoder applies fallback value for missing accentColor")
    func testPartialJSONDecodingFallback() throws {
        // Missing the 'accentColor' key
        let jsonString = """
        {
            "orgId": "org-456",
            "name": "Global Retail"
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        let snapshot = try decoder.decode(OrganizationSnapshot.self, from: data)
        
        #expect(snapshot.orgId == "org-456")
        #expect(snapshot.name == "Global Retail")
        
        // Verifies the fallback defined in init(from decoder:)
        #expect(snapshot.accentColor == "#FF5733")
    }
}
