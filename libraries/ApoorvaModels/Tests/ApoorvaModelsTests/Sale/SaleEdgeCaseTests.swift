//
//  SaleEdgeCaseTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("Sale Edge Case Tests")
struct SaleEdgeCaseTests {

    private func makeSale(id: String = "s1", items: [SaleItem] = [], overallDiscount: Double = 0, roundOff: Double = 0,
                          status: String = "Completed", returnOf: String? = nil, at seconds: TimeInterval = 100) -> Sale {
        Sale(id: id, staffId: "u1", customerPhone: "9", customerName: "Asha", items: items, subtotal: 0,
             overallDiscountPercent: 0, overallDiscountAmount: overallDiscount, roundOff: roundOff, netPayable: 0,
             payments: [:], timestamp: Date(timeIntervalSince1970: seconds), source: "pos", status: status,
             whatsappStatus: "unsent", returnOfSaleId: returnOf)
    }

    private func item(qty: Int, sticker: Double, final: Double) -> SaleItem {
        SaleItem(categoryId: "c", categoryName: "n", qty: qty, stickerPrice: sticker, finalPrice: final, discountType: .amount)
    }

    @Test("Empty sale has zero totals")
    func emptyTotals() {
        let sale = makeSale()
        #expect(sale.totalMRP == 0)
        #expect(sale.totalItemsDiscount == 0)
        #expect(sale.subTotal == 0)
        #expect(sale.billAmount == 0)
        #expect(sale.totalSavings == 0)
    }

    @Test("Totals multiply by quantity and include overall discount and round-off in savings")
    func totals() {
        let sale = makeSale(items: [item(qty: 2, sticker: 100, final: 90), item(qty: 1, sticker: 50, final: 50)],
                            overallDiscount: 10, roundOff: 2)
        #expect(sale.totalMRP == 250)
        #expect(sale.totalItemsDiscount == 20)
        #expect(sale.subTotal == 230)
        #expect(sale.billAmount == 220)
        #expect(sale.totalSavings == 32)
    }

    @Test("Items priced above sticker produce negative discount")
    func negativeDiscount() {
        let sale = makeSale(items: [item(qty: 1, sticker: 100, final: 120)])
        #expect(sale.totalItemsDiscount == -20)
        #expect(sale.subTotal == 120)
    }

    @Test("Cancelled status matches case-insensitively and nothing else")
    func cancelledStatus() {
        #expect(makeSale(status: "Cancelled").isCancelled)
        #expect(makeSale(status: "cancelled").isCancelled)
        #expect(makeSale(status: "CANCELLED").isCancelled)
        #expect(!makeSale(status: "Completed").isCancelled)
        #expect(!makeSale(status: "").isCancelled)
        #expect(!makeSale(status: "Cancelled ").isCancelled)
    }

    @Test("Return flag follows returnOfSaleId")
    func returnFlag() {
        #expect(makeSale(returnOf: "orig").isReturn)
        #expect(!makeSale().isReturn)
    }

    @Test("Decoding an empty object applies every fallback")
    func decodeEmpty() throws {
        let sale = try JSONDecoder().decode(Sale.self, from: Data("{}".utf8))
        #expect(sale.id.isEmpty)
        #expect(sale.staffId == "Unknown")
        #expect(sale.customerName == "Walk-in")
        #expect(sale.customerPhone.isEmpty)
        #expect(sale.items.isEmpty)
        #expect(sale.payments.isEmpty)
        #expect(sale.source == "Unknown")
        #expect(sale.status == "Completed")
        #expect(sale.whatsappStatus == "unsent")
        #expect(!sale.isDeleted)
        #expect(sale.cancelReason == nil)
        #expect(sale.returnOfSaleId == nil)
    }

    @Test("Payments map ignores unknown modes and keeps valid ones")
    func decodePaymentsMap() throws {
        let json = #"{"payments":{"cash":100,"upi":50.5,"bitcoin":9}}"#
        let sale = try JSONDecoder().decode(Sale.self, from: Data(json.utf8))
        #expect(sale.payments == [.cash: 100, .upi: 50.5])
    }

    @Test("Wrong-typed fields fall back instead of throwing")
    func decodeWrongTypes() throws {
        let json = #"{"id":5,"subtotal":"x","items":"nope","payments":"nope","isDeleted":"yes"}"#
        let sale = try JSONDecoder().decode(Sale.self, from: Data(json.utf8))
        #expect(sale.id.isEmpty)
        #expect(sale.subtotal == 0)
        #expect(sale.items.isEmpty)
        #expect(sale.payments.isEmpty)
        #expect(!sale.isDeleted)
    }

    @Test("Equality uses id only, ordering uses timestamp")
    func comparable() {
        let early = makeSale(id: "a", at: 1)
        let late = makeSale(id: "b", at: 2)
        #expect(early == makeSale(id: "a", at: 99))
        #expect(early != late)
        #expect(early < late)
        #expect(late > early)
        #expect(!(late < early))
    }

    @Test("Encoded sale keeps cancel and edit metadata")
    func roundTripMetadata() throws {
        let when = Date(timeIntervalSince1970: 5_000)
        let sale = Sale(id: "s1", staffId: "u", customerPhone: "9", customerName: "A", items: [], subtotal: 1,
                        overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 1,
                        payments: [.cash: 1], timestamp: when, source: "pos", status: "Cancelled", whatsappStatus: "sent",
                        updatedAt: when, cancelReason: "mistake", cancelledAt: when, cancelledBy: "u2",
                        editReason: "typo", editedAt: when, storeId: "st", billNumber: "A-1", returnOfSaleId: "s0")
        let decoded = try JSONDecoder().decode(Sale.self, from: JSONEncoder().encode(sale))
        #expect(decoded.cancelReason == "mistake")
        #expect(decoded.cancelledBy == "u2")
        #expect(decoded.editReason == "typo")
        #expect(decoded.storeId == "st")
        #expect(decoded.billNumber == "A-1")
        #expect(decoded.returnOfSaleId == "s0")
        #expect(decoded.payments[.cash] == 1)
    }
}
