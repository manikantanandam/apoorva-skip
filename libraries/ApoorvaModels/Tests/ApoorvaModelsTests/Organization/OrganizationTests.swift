//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name

@Suite("Organization Model Tests")
struct OrganizationTests {

    @Test("Standard initializer sets properties and defaults correctly")
    func testStandardInitialization() {
        let creationDate = Date(timeIntervalSince1970: 1600000000)
        let account = Account(id: "acc-1", name: "Main Bank", type: .bank, currentBalance: 100.0)
        
        let org = Organization(
            id: "org-123",
            name: "Apoorva Jewellers",
            status: "Active",
            createdAt: creationDate,
            minVersion: "1.2.0",
            currentTheme: "Dark",
            accentColor: "#000000",
            accounts: [account],
            establishedAtInMs: 1500000000000
        )
        
        #expect(org.id == "org-123")
        #expect(org.name == "Apoorva Jewellers")
        #expect(org.status == "Active")
        #expect(org.createdAt == creationDate)
        #expect(org.minVersion == "1.2.0")
        #expect(org.currentTheme == "Dark")
        #expect(org.accentColor == "#000000")
        #expect(org.accounts.count == 1)
        #expect(org.accounts.first?.name == "Main Bank")
        #expect(org.establishedAtInMs == 1500000000000)
        
        // Defaults from init
        #expect(org.isDeleted == false)
        #expect(org.updatedAt.timeIntervalSinceNow > -2.0)
    }

    @Test("Custom decoder handles complete JSON data correctly")
    func testFullJSONDecoding() throws {
        let jsonString = """
        {
            "id": "org-full",
            "name": "Global Retail",
            "status": "Inactive",
            "createdAt": 1700000000,
            "minVersion": "2.0.0",
            "currentTheme": "Light",
            "accentColor": "#FFFFFF",
            "accounts": [
                {
                    "id": "acc-2",
                    "name": "Cash Drawer",
                    "type": "cash",
                    "currentBalance": 500.0,
                    "updatedAt": 1700000000,
                    "isDeleted": false
                }
            ],
            "updatedAt": 1700005000,
            "isDeleted": true,
            "establishedAtInMs": 1400000000000
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let org = try decoder.decode(Organization.self, from: data)
        
        #expect(org.id == "org-full")
        #expect(org.name == "Global Retail")
        #expect(org.status == "Inactive")
        #expect(org.createdAt.timeIntervalSince1970 == 1700000000)
        #expect(org.minVersion == "2.0.0")
        #expect(org.currentTheme == "Light")
        #expect(org.accentColor == "#FFFFFF")
        #expect(org.accounts.count == 1)
        #expect(org.accounts.first?.type == .cash)
        #expect(org.updatedAt.timeIntervalSince1970 == 1700005000)
        #expect(org.isDeleted == true)
        #expect(org.establishedAtInMs == 1400000000000)
    }

    @Test("Custom decoder applies all fallback values for missing optional fields")
    func testPartialJSONDecodingFallbacks() throws {
        // Only providing the strictly required keys: name and createdAt
        let jsonString = """
        {
            "name": "Minimal Org",
            "createdAt": 1700000000
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let org = try decoder.decode(Organization.self, from: data)
        
        #expect(org.name == "Minimal Org")
        #expect(org.createdAt.timeIntervalSince1970 == 1700000000)
        
        // Verifying fallbacks defined in init(from decoder:)
        #expect(org.id == "")
        #expect(org.status == "Active")
        #expect(org.minVersion == "1.0.0")
        #expect(org.currentTheme == "Default")
        #expect(org.accentColor == "#FF5733")
        #expect(org.accounts.isEmpty)
        #expect(org.isDeleted == false)
        #expect(org.establishedAtInMs == 0)
        #expect(org.updatedAt.timeIntervalSinceNow > -2.0)
    }
    
    @Test("Organization encodes and decodes round-trip accurately")
    func testEncodingRoundTrip() throws {
        let originalOrg = Organization(
            id: "org-roundtrip",
            name: "Test Org",
            status: "Testing",
            createdAt: Date(),
            minVersion: "3.1.4",
            currentTheme: "Blue",
            accentColor: "#0000FF",
            accounts: [],
            updatedAt: Date(),
            isDeleted: false,
            establishedAtInMs: 123456789
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalOrg)
        
        let decoder = JSONDecoder()
        let decodedOrg = try decoder.decode(Organization.self, from: data)
        
        #expect(decodedOrg.id == originalOrg.id)
        #expect(decodedOrg.name == originalOrg.name)
        #expect(decodedOrg.status == originalOrg.status)
        #expect(decodedOrg.minVersion == originalOrg.minVersion)
        #expect(decodedOrg.currentTheme == originalOrg.currentTheme)
        #expect(decodedOrg.accentColor == originalOrg.accentColor)
        #expect(decodedOrg.establishedAtInMs == originalOrg.establishedAtInMs)
        #expect(decodedOrg.isDeleted == originalOrg.isDeleted)
    }
}
