//
//  StockMoneyPeopleTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("Stock, Money and People Model Tests")
struct StockMoneyPeopleTests {

    private let day = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 15))!

    // MARK: - Stock

    @Test("ItemCategory init stores values")
    func itemCategory() {
        let category = ItemCategory(name: "Rings", sortOrder: 2)
        #expect(ItemCategory.collection == "categories")
        #expect(category.name == "Rings")
        #expect(category.sortOrder == 2)
        #expect(!category.id.isEmpty)
        #expect(!category.isDeleted)
    }

    @Test("PurchaseLine total is rounded quantity times cost, id is itemId")
    func purchaseLine() {
        let line = PurchaseLine(itemId: "i1", itemName: "Pen", quantity: 2.5, unitCost: 10.1)
        #expect(line.id == "i1")
        #expect(line.total == 25)
    }

    @Test("Purchase on-credit never goes negative")
    func purchaseOnCredit() {
        let line = PurchaseLine(itemId: "i1", itemName: "Pen", quantity: 1, unitCost: 100)
        let partial = Purchase(number: "P-1", supplierId: "s1", supplierName: "Sup", lines: [line],
                               total: 100, paid: 40, createdBy: "u1")
        let over = Purchase(number: "P-2", supplierId: "s1", supplierName: "Sup", lines: [],
                            total: 100, paid: 150, createdBy: "u1")
        #expect(Purchase.collection == "purchases")
        #expect(partial.onCredit == 60)
        #expect(partial.paidMode == PaymentMode.cash.rawValue)
        #expect(!partial.isReturn)
        #expect(over.onCredit == 0)
    }

    @Test("Supplier ledger owed adds opening due and ignores other suppliers, deleted and opening entries")
    func supplierOwed() {
        let supplier = Supplier(id: "s1", name: "Sup", openingDue: 500)
        let entries = [
            SupplierLedgerEntry(supplierId: "s1", kind: .purchase, amount: 300, createdBy: "u"),
            SupplierLedgerEntry(supplierId: "s1", kind: .payment, amount: -100, createdBy: "u"),
            SupplierLedgerEntry(supplierId: "s1", kind: .opening, amount: 9999, createdBy: "u"),
            SupplierLedgerEntry(supplierId: "s2", kind: .purchase, amount: 777, createdBy: "u"),
            SupplierLedgerEntry(supplierId: "s1", kind: .purchase, amount: 888, createdBy: "u", isDeleted: true)
        ]
        #expect(entries.owed(to: supplier) == 700)
        #expect(SupplierLedgerEntry.collection == "supplierLedger")
    }

    // MARK: - Money

    @Test("ExpenseCategory titles")
    func expenseTitles() {
        let expected: [ExpenseCategory: String] = [
            .rent: "Rent", .salary: "Salary", .electricity: "Electricity", .transport: "Transport",
            .repairs: "Repairs", .supplier: "Supplier", .tea: "Tea & snacks", .other: "Other"
        ]
        for category in ExpenseCategory.allCases {
            #expect(category.title == expected[category])
        }
    }

    @Test("Expense defaults")
    func expenseDefaults() {
        let expense = Expense(title: "Shop rent", category: .rent, amount: 5000, createdBy: "u1")
        #expect(Expense.collection == "expenses")
        #expect(expense.mode == "cash")
        #expect(!expense.repeatsMonthly)
        #expect(expense.note.isEmpty)
    }

    @Test("dayKey formats dd-MM-yyyy")
    func dayKey() {
        #expect(day.dayKey == "07-03-2026")
    }

    @Test("DayClose uses dayKey id, normalises date and computes difference")
    func dayClose() {
        let close = DayClose(date: day, expectedCash: 1000, countedCash: 950, note: "short",
                             carryForward: true, closedBy: "u1", closedByName: "Asha")
        #expect(DayClose.collection == "dayCloses")
        #expect(close.id == "07-03-2026")
        #expect(close.date == Calendar.current.startOfDay(for: day))
        #expect(close.difference == -50)
        #expect(close.carryForward)
    }

    // MARK: - People

    @Test("AttendanceStatus titles and cycle")
    func attendanceStatus() {
        #expect(AttendanceStatus.half.title == "Half day")
        #expect(AttendanceStatus.present.next == .half)
        #expect(AttendanceStatus.half.next == .absent)
        #expect(AttendanceStatus.absent.next == .leave)
        #expect(AttendanceStatus.leave.next == .present)
    }

    @Test("AttendanceRecord id combines day key and member id")
    func attendanceRecord() {
        let record = AttendanceRecord(memberId: "m1", memberName: "Ravi", day: day, status: .present, markedBy: "u1")
        #expect(AttendanceRecord.collection == "attendance")
        #expect(record.id == "07-03-2026_m1")
        #expect(record.day == Calendar.current.startOfDay(for: day))
        #expect(record.inAt == nil)
    }

    @Test("SalaryPayment monthKey is yyyy-MM and defaults are set")
    func salaryPayment() {
        #expect(SalaryPayment.monthKey(day) == "2026-03")
        let payment = SalaryPayment(memberId: "m1", memberName: "Ravi", month: "2026-03",
                                    kind: .advance, amount: 2000, createdBy: "u1")
        #expect(SalaryPayment.collection == "salaryPayments")
        #expect(payment.mode == "cash")
        #expect(payment.kind == .advance)
    }
}
