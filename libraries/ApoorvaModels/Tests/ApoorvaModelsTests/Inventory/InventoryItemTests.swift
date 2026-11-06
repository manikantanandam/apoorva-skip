//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaModels // Update with your actual module name
@testable import ApoorvaUtilities // Required for SortType

@Suite("InventoryItem Model Tests")
struct InventoryItemTests {
    
    // MARK: - Initialization Tests
    
    @Test("Standard initializer sets default values correctly")
    func testStandardInitialization() {
        let item = InventoryItem(name: "Gold Ring")
        
        #expect(!item.id.isEmpty)
        #expect(item.name == "Gold Ring")
        #expect(item.currentStock == 0)
        #expect(item.billMachineNumber == 0)
        #expect(item.lastSoldDate == nil)
        #expect(item.isHotkey == false)
        #expect(item.updatedAt == nil)
        #expect(item.isDeleted == false)
    }
    
    // MARK: - Decoding Tests
    
    @Test("Custom decoder handles complete JSON data")
    func testFullJSONDecoding() throws {
        let jsonString = """
        {
            "id": "item-123",
            "name": "Silver Chain",
            "currentStock": 50,
            "billMachineNumber": 2,
            "isHotkey": true,
            "isDeleted": false,
            "lastSoldDate": 1700000000,
            "updatedAt": 1700005000
        }
        """
        let data = try #require(jsonString.data(using: .utf8))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let item = try decoder.decode(InventoryItem.self, from: data)
        
        #expect(item.id == "item-123")
        #expect(item.name == "Silver Chain")
        #expect(item.currentStock == 50)
        #expect(item.billMachineNumber == 2)
        #expect(item.isHotkey == true)
        #expect(item.isDeleted == false)
        #expect(item.lastSoldDate?.timeIntervalSince1970 == 1700000000)
        #expect(item.updatedAt?.timeIntervalSince1970 == 1700005000)
    }
    
    @Test("Custom decoder applies fallbacks for missing or invalid fields")
    func testPartialJSONDecodingFallbacks() throws {
        // Empty JSON to trigger all fallbacks
        let jsonString = "{}"
        let data = try #require(jsonString.data(using: .utf8))
        
        let item = try JSONDecoder().decode(InventoryItem.self, from: data)
        
        #expect(item.id == "")
        #expect(item.name == "Unknown Category")
        #expect(item.currentStock == 0)
        #expect(item.billMachineNumber == 0)
        #expect(item.isHotkey == false)
        #expect(item.isDeleted == false)
        #expect(item.lastSoldDate == nil)
        #expect(item.updatedAt == nil)
    }
    
    // MARK: - Computed Properties Tests
    
    @Test("Date string formatting returns fallback when dates are nil")
    func testDateStringFallbacks() {
        let item = InventoryItem(name: "Test", lastSoldDate: nil, updatedAt: nil)
        
        #expect(item.lastSoldDateString == "Not Available")
        #expect(item.updatedAtString == "Not Available")
    }
    
    @Test("Date string formatting returns formatted string when dates exist")
    func testDateStringFormatting() {
        let date = Date()
        let item = InventoryItem(name: "Test", lastSoldDate: date, updatedAt: date)
        
        let expectedFormat = date.formatted(date: .abbreviated, time: .shortened)
        
        #expect(item.lastSoldDateString == expectedFormat)
        #expect(item.updatedAtString == expectedFormat)
    }
    
    // MARK: - Comparable Test
    
    @Test("InventoryItem comparable sorting by name")
    func testComparableSorting() {
        let apple = InventoryItem(name: "Apple")
        let banana = InventoryItem(name: "Banana")
        
        #expect(apple < banana)
    }
    
    // MARK: - Array Extension Tests
    
    @Test("Array sortByName correctly sorts items")
    func testSortByName() {
        var items = [
            InventoryItem(name: "Banana"),
            InventoryItem(name: "Apple"),
            InventoryItem(name: "Cherry")
        ]
        
        // Note: The implementation in InventoryItem.swift uses > for .ascending (Z-A) and < for .descending (A-Z)
        items.sortByName(type: .ascending)
        #expect(items[0].name == "Cherry")
        #expect(items[1].name == "Banana")
        #expect(items[2].name == "Apple")
        
        items.sortByName(type: .descending)
        #expect(items[0].name == "Apple")
        #expect(items[1].name == "Banana")
        #expect(items[2].name == "Cherry")
    }
    
    @Test("Array sortByStockLevel correctly sorts items")
    func testSortByStockLevel() {
        var items = [
            InventoryItem(name: "A", currentStock: 10),
            InventoryItem(name: "B", currentStock: 50),
            InventoryItem(name: "C", currentStock: 5)
        ]
        
        // Note: Implementation uses > for .ascending and < for .descending
        items.sortByStockLevel(type: .ascending)
        #expect(items[0].currentStock == 50)
        #expect(items[1].currentStock == 10)
        #expect(items[2].currentStock == 5)
        
        items.sortByStockLevel(type: .descending)
        #expect(items[0].currentStock == 5)
        #expect(items[1].currentStock == 10)
        #expect(items[2].currentStock == 50)
    }
    
    @Test("Array sortByLastSoldDate correctly sorts items")
    func testSortByLastSoldDate() {
        let past = Date(timeIntervalSince1970: 1000)
        let present = Date(timeIntervalSince1970: 2000)
        
        var items = [
            InventoryItem(name: "A", lastSoldDate: past),
            InventoryItem(name: "B", lastSoldDate: present),
            InventoryItem(name: "C", lastSoldDate: nil) // Falls back to distantPast
        ]
        
        // Note: Implementation uses > for .ascending and < for .descending
        items.sortByLastSoldDate(type: .ascending)
        #expect(items[0].name == "B") // present
        #expect(items[1].name == "A") // past
        #expect(items[2].name == "C") // distantPast
        
        items.sortByLastSoldDate(type: .descending)
        #expect(items[0].name == "C")
        #expect(items[1].name == "A")
        #expect(items[2].name == "B")
    }
    
    @Test("Array hotItems filter returns only items with isHotkey true")
    func testHotItemsFilter() {
        let items = [
            InventoryItem(name: "A", isHotkey: true),
            InventoryItem(name: "B", isHotkey: false),
            InventoryItem(name: "C", isHotkey: true)
        ]
        
        let hotItems = items.hotItems
        
        #expect(hotItems.count == 2)
        #expect(hotItems.contains(where: { $0.name == "A" }))
        #expect(hotItems.contains(where: { $0.name == "C" }))
        #expect(!hotItems.contains(where: { $0.name == "B" }))
    }
}
