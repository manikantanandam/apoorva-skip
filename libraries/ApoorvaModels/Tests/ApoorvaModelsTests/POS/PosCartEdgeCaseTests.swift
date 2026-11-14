//
//  PosCartEdgeCaseTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("PosCart Edge Case Tests")
struct PosCartEdgeCaseTests {

    private func line(_ mrp: Double, qty: Int = 1, discount: Double = 0, weight: Double? = nil) -> CartItem {
        CartItem(category: InventoryItem(name: "X"), mrp: mrp, discountPercent: discount, quantity: qty, weight: weight)
    }

    @Test("Decoding an empty object uses defaults")
    func decodeEmpty() throws {
        let cart = try JSONDecoder().decode(PosCart.self, from: Data("{}".utf8))
        #expect(cart.items.isEmpty)
        #expect(cart.flatDiscount == 0)
        #expect(cart.paymentMode == .cash)
        #expect(cart.customerPhone == nil)
        #expect(cart.priceTier == nil)
        #expect(cart.discountPercent == nil)
        #expect(cart.returnOfSaleId == nil)
    }

    @Test("Unknown payment mode falls back to cash")
    func unknownPaymentMode() throws {
        let cart = try JSONDecoder().decode(PosCart.self, from: Data(#"{"paymentMode":"barter"}"#.utf8))
        #expect(cart.paymentMode == .cash)
    }

    @Test("Weighed lines count their weight in totals but one in item count")
    func weighedLines() {
        let cart = PosCart(items: [line(100, weight: 0.5), line(10, qty: 3)])
        #expect(cart.totalMRP == 80)
        #expect(cart.totalFinalPrice == 80)
        #expect(cart.totalItemsCount == 4)
    }

    @Test("Discount on MRP is MRP minus final price")
    func discountOnMRP() {
        let cart = PosCart(items: [line(200, qty: 2, discount: 25)])
        #expect(cart.totalMRP == 400)
        #expect(cart.totalFinalPrice == 300)
        #expect(cart.totalDiscountOnMRP == 100)
    }

    @Test("Payable is exactly zero when the flat discount equals the total")
    func payableAtBoundary() {
        #expect(PosCart(items: [line(100)], flatDiscount: 100).totalPayable == 0)
        #expect(PosCart(items: [line(100)], flatDiscount: 150).totalPayable == 0)
        #expect(PosCart(items: [line(100)], flatDiscount: 99.5).totalPayable == 0.5)
    }

    @Test("Empty cart with a flat discount stays at zero")
    func emptyWithDiscount() {
        let cart = PosCart(flatDiscount: 50)
        #expect(cart.totalPayable == 0)
        #expect(cart.totalItemsCount == 0)
    }

    @Test("Return and tier metadata survive a round-trip")
    func roundTrip() throws {
        let cart = PosCart(items: [line(10)], flatDiscount: 1, paymentMode: .upi, customerPhone: "9", customerName: "A",
                           socialSource: "instagram", priceTier: "wholesale", discountPercent: 10, returnOfSaleId: "s0")
        let decoded = try JSONDecoder().decode(PosCart.self, from: JSONEncoder().encode(cart))
        #expect(decoded.paymentMode == .upi)
        #expect(decoded.socialSource == "instagram")
        #expect(decoded.priceTier == "wholesale")
        #expect(decoded.discountPercent == 10)
        #expect(decoded.returnOfSaleId == "s0")
        #expect(decoded.items.count == 1)
    }
}
