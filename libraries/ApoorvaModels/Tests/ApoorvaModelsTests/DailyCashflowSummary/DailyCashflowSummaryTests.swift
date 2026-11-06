//
//  DailyCashflowSummaryTests.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 06/11/26.
//

import Testing
import Foundation
import ApoorvaUtilities
@testable import ApoorvaModels

@Suite("DailyCashflowSummary Model Tests")
struct DailyCashflowSummaryTests {

    private let sampleDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeSummary(
        date: Date? = nil,
        opening: [AccountBalance] = [],
        closing: [AccountBalance] = [],
        locked: Bool = false
    ) -> DailyCashflowSummary {
        DailyCashflowSummary(
            date: date ?? sampleDate,
            openingBalances: opening,
            closingBalances: closing,
            updatedAt: 1_700_000_999,
            locked: locked
        )
    }

    // MARK: - AccountBalance

    @Test("AccountBalance memberwise init stores its values")
    func testAccountBalanceInit() {
        let balance = AccountBalance(id: "acc-1", name: "Cash", balance: 250.75)

        #expect(balance.id == "acc-1")
        #expect(balance.name == "Cash")
        #expect(balance.balance == 250.75)
    }

    @Test("AccountBalance balance is mutable")
    func testAccountBalanceMutation() {
        var balance = AccountBalance(id: "acc-1", name: "Cash", balance: 10)
        balance.balance = 99

        #expect(balance.balance == 99)
    }

    @Test("AccountBalance round trips through Codable")
    func testAccountBalanceRoundTrip() throws {
        let original = AccountBalance(id: "acc-2", name: "UPI", balance: -12.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AccountBalance.self, from: data)

        #expect(decoded.id == "acc-2")
        #expect(decoded.name == "UPI")
        #expect(decoded.balance == -12.5)
    }

    @Test("AccountBalance throws when a required key is missing")
    func testAccountBalanceMissingKey() {
        let json = #"{"id": "acc-3", "name": "Bank"}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AccountBalance.self, from: Data(json.utf8))
        }
    }

    // MARK: - Initializer and id

    @Test("id is derived from the date in dd-MM-yyyy format")
    func testIdFormatting() {
        let summary = makeSummary()

        #expect(summary.id == sampleDate.toString(format: "dd-MM-yyyy"))
        #expect(!summary.id.isEmpty)
    }

    @Test("Stored properties match the initializer arguments")
    func testStoredProperties() {
        let opening = [AccountBalance(id: "a", name: "Cash", balance: 100)]
        let closing = [AccountBalance(id: "a", name: "Cash", balance: 150)]
        let summary = makeSummary(opening: opening, closing: closing, locked: true)

        #expect(summary.date == sampleDate)
        #expect(summary.openingBalances.count == 1)
        #expect(summary.closingBalances.count == 1)
        #expect(summary.updatedAt == 1_700_000_999)
        #expect(summary.locked == true)
    }

    // MARK: - Totals

    @Test("Totals are zero when there are no balances")
    func testTotalsEmpty() {
        let summary = makeSummary()

        #expect(summary.totalOpening == 0)
        #expect(summary.totalClosing == 0)
    }

    @Test("Totals sum every balance in each list")
    func testTotalsSum() {
        let summary = makeSummary(
            opening: [
                AccountBalance(id: "a", name: "Cash", balance: 100),
                AccountBalance(id: "b", name: "UPI", balance: 50.5),
                AccountBalance(id: "c", name: "Bank", balance: -20)
            ],
            closing: [
                AccountBalance(id: "a", name: "Cash", balance: 200),
                AccountBalance(id: "b", name: "UPI", balance: 0)
            ]
        )

        #expect(summary.totalOpening == 130.5)
        #expect(summary.totalClosing == 200)
    }

    // MARK: - copyWith

    @Test("copyWith with no arguments preserves every field and the id")
    func testCopyWithNoArguments() {
        let original = makeSummary(
            opening: [AccountBalance(id: "a", name: "Cash", balance: 10)],
            locked: true
        )
        let copy = original.copyWith()

        #expect(copy.id == original.id)
        #expect(copy.date == original.date)
        #expect(copy.openingBalances.count == 1)
        #expect(copy.closingBalances.isEmpty)
        #expect(copy.updatedAt == original.updatedAt)
        #expect(copy.locked == true)
    }

    @Test("copyWith replaces the balances, timestamp and lock state")
    func testCopyWithBalancesAndFlags() {
        let original = makeSummary()
        let newOpening = [AccountBalance(id: "a", name: "Cash", balance: 5)]
        let newClosing = [AccountBalance(id: "a", name: "Cash", balance: 7)]

        let copy = original.copyWith(
            openingBalances: newOpening,
            closingBalances: newClosing,
            updatedAt: 1_800_000_000,
            locked: true
        )

        #expect(copy.openingBalances.first?.balance == 5)
        #expect(copy.closingBalances.first?.balance == 7)
        #expect(copy.updatedAt == 1_800_000_000)
        #expect(copy.locked == true)
        #expect(copy.id == original.id)
        #expect(copy.date == original.date)
    }

    @Test("copyWith with a new date recalculates the id")
    func testCopyWithDateRecalculatesId() {
        let original = makeSummary()
        let newDate = Date(timeIntervalSince1970: 1_800_000_000)

        let copy = original.copyWith(date: newDate)

        #expect(copy.date == newDate)
        #expect(copy.id == newDate.toString(format: "dd-MM-yyyy"))
        #expect(copy.id != original.id)
    }

    @Test("copyWith does not mutate the original instance")
    func testCopyWithDoesNotMutateOriginal() {
        let original = makeSummary(locked: false)
        _ = original.copyWith(locked: true)

        #expect(original.locked == false)
    }

    // MARK: - Codable

    @Test("DailyCashflowSummary round trips through Codable")
    func testCodableRoundTrip() throws {
        let original = makeSummary(
            opening: [AccountBalance(id: "a", name: "Cash", balance: 100)],
            closing: [AccountBalance(id: "a", name: "Cash", balance: 120)],
            locked: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DailyCashflowSummary.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.date == original.date)
        #expect(decoded.openingBalances.first?.balance == 100)
        #expect(decoded.closingBalances.first?.balance == 120)
        #expect(decoded.updatedAt == original.updatedAt)
        #expect(decoded.locked == true)
        #expect(decoded.totalClosing == 120)
    }
}
