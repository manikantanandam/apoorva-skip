//
//  CartItemExtraTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("CartItem Extra Tests")
struct CartItemExtraTests {

    @Test("Line id defaults to category id, or category id plus variant")
    func lineId() {
        let category = InventoryItem(name: "Bangles")
        #expect(CartItem(category: category, mrp: 10, quantity: 1).lineId == category.id)
        #expect(CartItem(category: category, mrp: 10, quantity: 1, variant: "2.4").lineId == "\(category.id)#2.4")
        #expect(CartItem(category: category, mrp: 10, quantity: 1, lineId: "custom").id == "custom")
    }

    @Test("Display name combines name, variant and weight")
    func displayName() {
        let category = InventoryItem(name: "Toor Dal")
        #expect(CartItem(category: category, mrp: 10, quantity: 1).displayName == "Toor Dal")
        #expect(CartItem(category: category, mrp: 10, quantity: 1, variant: "Ruby").displayName == "Toor Dal · Ruby")
        #expect(CartItem(category: category, mrp: 10, quantity: 1, weight: 2, unit: "l").displayName == "Toor Dal · 2 l")
        #expect(CartItem(category: category, mrp: 10, quantity: 1, weight: 0.5).displayName == "Toor Dal · 0.5 kg")
    }

    @Test("Weighed lines use weight as the measure")
    func weighedMeasure() {
        let category = InventoryItem(name: "Rice")
        let item = CartItem(category: category, mrp: 60, quantity: 1, weight: 2.5, unit: "kg")
        #expect(item.measure == 2.5)
        #expect(item.lineMRP == 150)
        #expect(item.totalItemsPrice == 150)

        let counted = CartItem(category: category, mrp: 60, quantity: 3)
        #expect(counted.measure == 3)
    }

    @Test("Decoding applies defaults for optional fields")
    func decodeDefaults() throws {
        let original = CartItem(category: InventoryItem(name: "Pen"), mrp: 10, discountPercent: 0, quantity: 2)
        let data = try JSONEncoder().encode(original)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["discountPercent", "discountType", "weight", "unit", "variant", "doneByStaffId", "doneByName", "warrantyMonths", "lineId"] {
            object.removeValue(forKey: key)
        }
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(CartItem.self, from: stripped)

        #expect(decoded.discountPercent == 0)
        #expect(decoded.discountType == .percentage)
        #expect(decoded.weight == nil)
        #expect(decoded.variant == nil)
        #expect(decoded.warrantyMonths == nil)
        #expect(decoded.lineId == decoded.category.id)
        #expect(decoded.quantity == 2)
    }

    @Test("Round-trip keeps staff, warranty and variant details")
    func roundTrip() throws {
        let item = CartItem(category: InventoryItem(name: "Facial"), mrp: 500, discountPercent: 10, quantity: 1,
                            discountType: .amount, variant: "Gold", doneByStaffId: "m1", doneByName: "Ravi",
                            warrantyMonths: 3)
        let decoded = try JSONDecoder().decode(CartItem.self, from: JSONEncoder().encode(item))
        #expect(decoded.discountType == .amount)
        #expect(decoded.variant == "Gold")
        #expect(decoded.doneByStaffId == "m1")
        #expect(decoded.doneByName == "Ravi")
        #expect(decoded.warrantyMonths == 3)
        #expect(decoded.lineId == item.lineId)
    }
}
