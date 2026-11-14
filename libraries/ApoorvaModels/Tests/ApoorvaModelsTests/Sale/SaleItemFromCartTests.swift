//
//  SaleItemFromCartTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("SaleItem From CartItem Tests")
struct SaleItemFromCartTests {

    @Test("Regular cart line keeps quantity, MRP and final price")
    func regularLine() {
        let cart = CartItem(category: InventoryItem(name: "Ring"), mrp: 200, discountPercent: 10, quantity: 2,
                            discountType: .percentage, variant: "Ruby", doneByStaffId: "m1", doneByName: "Ravi",
                            warrantyMonths: 6)
        let item = SaleItem(cartItem: cart)

        #expect(item.categoryId == cart.category.id)
        #expect(item.categoryName == "Ring · Ruby")
        #expect(item.qty == 2)
        #expect(item.stickerPrice == 200)
        #expect(item.finalPrice == 180)
        #expect(item.discountType == .percentage)
        #expect(item.doneByStaffId == "m1")
        #expect(item.doneByName == "Ravi")
        #expect(item.warrantyMonths == 6)
        #expect(item.variant == "Ruby")
        #expect(item.weight == nil)
        #expect(item.totalAmount == 360)
    }

    @Test("Weighed cart line becomes one unit priced at the line amount")
    func weighedLine() {
        let cart = CartItem(category: InventoryItem(name: "Toor Dal"), mrp: 100, discountPercent: 10, quantity: 1,
                            weight: 0.5, unit: "kg")
        let item = SaleItem(cartItem: cart)

        #expect(item.categoryName == "Toor Dal · 0.5 kg")
        #expect(item.qty == 1)
        #expect(item.stickerPrice == 50)
        #expect(item.finalPrice == 45)
        #expect(item.weight == 0.5)
        #expect(item.unit == "kg")
        #expect(item.totalAmount == 45)
    }

    @Test("Encoding uses the cat_id key and round-trips")
    func encodeRoundTrip() throws {
        let item = SaleItem(categoryId: "c1", categoryName: "Pen", qty: 3, stickerPrice: 10, finalPrice: 8,
                            discountType: .amount, doneByStaffId: "m1", doneByName: "Ravi", warrantyMonths: 12,
                            weight: 1.5, unit: "kg", variant: "Blue")
        let data = try JSONEncoder().encode(item)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"cat_id\""))

        let decoded = try JSONDecoder().decode(SaleItem.self, from: data)
        #expect(decoded.categoryId == "c1")
        #expect(decoded.qty == 3)
        #expect(decoded.discountType == .amount)
        #expect(decoded.doneByStaffId == "m1")
        #expect(decoded.doneByName == "Ravi")
        #expect(decoded.warrantyMonths == 12)
        #expect(decoded.weight == 1.5)
        #expect(decoded.unit == "kg")
        #expect(decoded.variant == "Blue")
    }

    @Test("Unit discount amount is sticker minus final")
    func unitDiscount() {
        let item = SaleItem(categoryId: "c", categoryName: "n", qty: 1, stickerPrice: 100, finalPrice: 75, discountType: .finalPrice)
        #expect(item.unitDiscountAmount == 25)
        #expect(item.discountPercent == 25)
    }
}
