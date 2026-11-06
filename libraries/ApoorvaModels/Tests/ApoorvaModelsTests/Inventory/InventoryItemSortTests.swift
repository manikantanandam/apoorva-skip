//
//  InventoryItemSortTests.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 06/11/26.
//

import Testing
import Foundation
import ApoorvaUtilities
@testable import ApoorvaModels

@Suite("InventoryItem Sort Coverage Tests")
struct InventoryItemSortTests {

    @Test("sortByName descending orders A to Z case-insensitively")
    func testSortByNameDescending() {
        var items = [
            InventoryItem(name: "banana"),
            InventoryItem(name: "Apple"),
            InventoryItem(name: "cherry")
        ]
        items.sortByName(type: .descending)

        #expect(items.map(\.name) == ["Apple", "banana", "cherry"])
    }

    @Test("sortByStockLevel descending orders lowest stock first")
    func testSortByStockLevelDescending() {
        var items = [
            InventoryItem(name: "A", currentStock: 5),
            InventoryItem(name: "B", currentStock: 1),
            InventoryItem(name: "C", currentStock: 9)
        ]
        items.sortByStockLevel(type: .descending)

        #expect(items.map(\.currentStock) == [1, 5, 9])
    }

    @Test("sortByLastSoldDate descending puts nil dates first (distant past)")
    func testSortByLastSoldDateDescendingWithNil() {
        let recent = Date(timeIntervalSince1970: 3000)
        var items = [
            InventoryItem(name: "Recent", lastSoldDate: recent),
            InventoryItem(name: "Never")
        ]
        items.sortByLastSoldDate(type: .descending)

        #expect(items.map(\.name) == ["Never", "Recent"])
    }

    @Test("sortByLastSoldDate ascending puts nil dates last")
    func testSortByLastSoldDateAscendingWithNil() {
        let recent = Date(timeIntervalSince1970: 3000)
        var items = [
            InventoryItem(name: "Never"),
            InventoryItem(name: "Recent", lastSoldDate: recent)
        ]
        items.sortByLastSoldDate(type: .ascending)

        #expect(items.map(\.name) == ["Recent", "Never"])
    }

    @Test("sortByUpdatedAt ascending orders newest first and treats nil as oldest")
    func testSortByUpdatedAtAscending() {
        var items = [
            InventoryItem(name: "Old", updatedAt: Date(timeIntervalSince1970: 1000)),
            InventoryItem(name: "Nil"),
            InventoryItem(name: "New", updatedAt: Date(timeIntervalSince1970: 2000))
        ]
        items.sortByUpdatedAt(type: .ascending)

        #expect(items.map(\.name) == ["New", "Old", "Nil"])
    }

    @Test("sortByUpdatedAt descending orders oldest first and treats nil as oldest")
    func testSortByUpdatedAtDescending() {
        var items = [
            InventoryItem(name: "New", updatedAt: Date(timeIntervalSince1970: 2000)),
            InventoryItem(name: "Old", updatedAt: Date(timeIntervalSince1970: 1000)),
            InventoryItem(name: "Nil")
        ]
        items.sortByUpdatedAt(type: .descending)

        #expect(items.map(\.name) == ["Nil", "Old", "New"])
    }
}
