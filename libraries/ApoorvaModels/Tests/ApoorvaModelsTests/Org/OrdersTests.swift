//
//  OrdersTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("Orders Model Tests")
struct OrdersTests {

    private func makeOrder(total: Double = 1000, advance: Double = 300,
                           readyBy: Date = Date(), status: OrderStatus = .open) -> Order {
        Order(number: "O-1", customerPhone: "9999999999", customerName: "Asha", details: "Ring resize",
              total: total, advance: advance, readyBy: readyBy, status: status, createdBy: "u1")
    }

    private func entry(_ amount: Double, at date: Date, deleted: Bool = false) -> CustomerLedgerEntry {
        CustomerLedgerEntry(customerPhone: "9999999999", customerName: "Asha",
                            kind: amount >= 0 ? .sale : .payment, amount: amount,
                            createdAt: date, createdBy: "u1", isDeleted: deleted)
    }

    @Test("Enum titles are capitalised")
    func enumTitles() {
        #expect(OrderStatus.open.title == "Open")
        #expect(OrderStatus.cancelled.title == "Cancelled")
        #expect(OrderFulfilment.delivery.title == "Delivery")
        #expect(WarrantyAction.refund.title == "Refund")
    }

    @Test("Order defaults and collection name")
    func orderDefaults() {
        let order = makeOrder()
        #expect(Order.collection == "orders")
        #expect(order.advanceMode == PaymentMode.cash.rawValue)
        #expect(order.fulfilment == .pickup)
        #expect(order.notifyWhenReady)
        #expect(order.status == .open)
        #expect(!order.isDeleted)
    }

    @Test("Balance is total minus advance and never negative")
    func orderBalance() {
        #expect(makeOrder(total: 1000, advance: 300).balance == 700)
        #expect(makeOrder(total: 100, advance: 300).balance == 0)
    }

    @Test("Order is overdue only when open and ready-by is before today")
    func orderOverdue() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        #expect(makeOrder(readyBy: yesterday).isOverdue)
        #expect(!makeOrder(readyBy: tomorrow).isOverdue)
        #expect(!makeOrder(readyBy: yesterday, status: .delivered).isOverdue)
    }

    @Test("Order round-trips through Codable")
    func orderCodable() throws {
        let order = makeOrder()
        let decoded = try JSONDecoder().decode(Order.self, from: JSONEncoder().encode(order))
        #expect(decoded.id == order.id)
        #expect(decoded.total == order.total)
        #expect(decoded.status == order.status)
    }

    @Test("WarrantyClaim stores its fields")
    func warrantyClaim() {
        let claim = WarrantyClaim(saleId: "s1", billNumber: "B-1", itemId: "i1", itemName: "Watch",
                                  customerPhone: "9", action: .repair, note: "Strap", createdBy: "u1")
        #expect(WarrantyClaim.collection == "warrantyClaims")
        #expect(claim.action == .repair)
        #expect(claim.saleId == "s1")
        #expect(!claim.isDeleted)
    }

    @Test("CustomerStatement splits opening, bills and payments by period")
    func statement() {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let end = cal.date(from: DateComponents(year: 2026, month: 5, day: 31))!
        let before = cal.date(from: DateComponents(year: 2026, month: 4, day: 10))!
        let inside1 = cal.date(from: DateComponents(year: 2026, month: 5, day: 5))!
        let inside2 = cal.date(from: DateComponents(year: 2026, month: 5, day: 20))!
        let after = cal.date(from: DateComponents(year: 2026, month: 6, day: 2))!

        let statement = CustomerStatement(entries: [
            entry(200, at: before),
            entry(500, at: inside1),
            entry(-300, at: inside2),
            entry(999, at: after),
            entry(777, at: inside1, deleted: true)
        ], from: start, to: end)

        #expect(statement.opening == 200)
        #expect(statement.bills == 500)
        #expect(statement.payments == 300)
        #expect(statement.closing == 400)
        #expect(statement.entries.count == 2)
        #expect(statement.entries.first?.createdAt == inside1)
    }

    @Test("CustomerStatement equality compares totals and entry ids")
    func statementEquality() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 1000)
        let e = entry(100, at: Date(timeIntervalSince1970: 500))
        let a = CustomerStatement(entries: [e], from: start, to: end)
        let b = CustomerStatement(entries: [e], from: start, to: end)
        let c = CustomerStatement(entries: [], from: start, to: end)
        #expect(a == b)
        #expect(a != c)
    }
}
