//
//  InventoryItemEdgeCaseTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("InventoryItem Edge Case Tests")
struct InventoryItemEdgeCaseTests {

    @Test("Low stock uses 5 by default and is inclusive of the threshold")
    func lowStockBoundaries() {
        #expect(InventoryItem(name: "A", currentStock: 5).isLowStock)
        #expect(!InventoryItem(name: "A", currentStock: 6).isLowStock)
        #expect(InventoryItem(name: "A", currentStock: 0).isLowStock)
        #expect(InventoryItem(name: "A", currentStock: -3).isLowStock)
    }

    @Test("Custom threshold overrides the default")
    func customThreshold() {
        #expect(!InventoryItem(name: "A", currentStock: 6, lowStockThreshold: 2).isLowStock)
        #expect(InventoryItem(name: "A", currentStock: 2, lowStockThreshold: 2).isLowStock)
        #expect(InventoryItem(name: "A", currentStock: 0, lowStockThreshold: 0).isLowStock)
        #expect(!InventoryItem(name: "A", currentStock: 1, lowStockThreshold: 0).isLowStock)
    }

    @Test("Decoding an empty object applies fallbacks")
    func decodeEmpty() throws {
        let item = try JSONDecoder().decode(InventoryItem.self, from: Data("{}".utf8))
        #expect(item.id.isEmpty)
        #expect(item.name == "Unknown Category")
        #expect(item.currentStock == 0)
        #expect(!item.isHotkey)
        #expect(!item.isDeleted)
        #expect(item.barcode == nil)
        #expect(item.imageURLs == nil)
    }

    @Test("Wrong-typed values are ignored rather than throwing")
    func decodeWrongTypes() throws {
        let json = #"{"name":7,"currentStock":"many","lastSoldDate":"yesterday","sellPrice":"free","imageURLs":"x"}"#
        let item = try JSONDecoder().decode(InventoryItem.self, from: Data(json.utf8))
        #expect(item.name == "Unknown Category")
        #expect(item.currentStock == 0)
        #expect(item.lastSoldDate == nil)
        #expect(item.sellPrice == nil)
        #expect(item.imageURLs == nil)
    }

    @Test("Sorting empty and single-element arrays is safe")
    func sortEmptyAndSingle() {
        var empty = [InventoryItem]()
        empty.sortByName(type: .ascending)
        empty.sortByStockLevel(type: .descending)
        empty.sortByLastSoldDate(type: .ascending)
        empty.sortByUpdatedAt(type: .descending)
        #expect(empty.isEmpty)

        var single = [InventoryItem(name: "Only")]
        single.sortByName(type: .descending)
        #expect(single.count == 1)
    }

    @Test("Name sorting ignores case")
    func sortIgnoresCase() {
        var items = [InventoryItem(name: "banana"), InventoryItem(name: "Apple"), InventoryItem(name: "cherry")]
        items.sortByName(type: .descending)
        #expect(items.map(\.name) == ["Apple", "banana", "cherry"])
    }

    @Test("Items that were never sold group together when sorting by last sold date")
    func neverSoldGroup() {
        let sold = InventoryItem(name: "Sold", lastSoldDate: Date(timeIntervalSince1970: 100))
        var items = [InventoryItem(name: "N1"), sold, InventoryItem(name: "N2")]
        items.sortByLastSoldDate(type: .descending)
        #expect(items.last?.name == "Sold")
    }

    @Test("Hot items is empty when none are flagged")
    func noHotItems() {
        #expect([InventoryItem(name: "A"), InventoryItem(name: "B")].hotItems.isEmpty)
        #expect([InventoryItem]().hotItems.isEmpty)
    }

    @Test("Comparable orders by exact name")
    func comparable() {
        #expect(InventoryItem(name: "Apple") < InventoryItem(name: "Banana"))
        #expect(!(InventoryItem(name: "Apple") < InventoryItem(name: "Apple")))
    }
}
