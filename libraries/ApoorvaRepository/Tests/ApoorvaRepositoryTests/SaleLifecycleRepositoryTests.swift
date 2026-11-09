//
//  SaleLifecycleRepositoryTests.swift
//  ApoorvaRepository
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaOfflineStorage
@testable import ApoorvaServices
@testable import ApoorvaRepository

final class LifecycleSaleRepository: SaleRepositoryProtocol, @unchecked Sendable {
    var sales: [String: Sale] = [:]
    func getSales() async throws -> [Sale] { Array(sales.values) }
    func getSale(id: String) async throws -> Sale? { sales[id] }
    func saveSale(sale: Sale) async throws { sales[sale.id] = sale }
    func updateSale(_ sale: Sale) async throws { sales[sale.id] = sale }
    func deleteSale(id: String) async throws {}
    func markAsDeleted(id: String) async throws {}
    func confirmSale(_ sale: Sale, heldBillId: String?) async throws { sales[sale.id] = sale }
    func cancelSale(id: String, reason: String, by staffId: String) async throws -> Sale? {
        guard var sale = sales[id], !sale.isCancelled else { return nil }
        sale.status = "Cancelled"
        sale.cancelReason = reason
        sales[id] = sale
        return sale
    }
    func editSale(_ sale: Sale, reason: String) async throws {
        var edited = sale
        edited.editReason = reason
        sales[sale.id] = edited
    }
    func sync(force: Bool) async throws {}
}

final class LifecycleInventoryRepository: InventoryItemRepositoryProtocol, @unchecked Sendable {
    var items: [String: InventoryItem] = [:]
    func getInventoryItems() async throws -> [InventoryItem] { Array(items.values) }
    func saveInventoryItem(item: InventoryItem) async throws { items[item.id] = item }
    func updateInventoryItem(_ item: InventoryItem) async throws { items[item.id] = item }
    func deleteInventoryItem(id: String) async throws {}
    func markAsDeleted(id: String) async throws {}
    func sync(force: Bool) async throws {}
    func lastSyncedAt() async throws -> Date? { nil }
}

final class LifecycleCustomerRepository: CustomerRepositoryProtocol, @unchecked Sendable {
    var customers: [String: Customer] = [:]
    func getCustomers() async throws -> [Customer] { Array(customers.values) }
    func saveCustomer(customer: Customer) async throws { customers[customer.phone] = customer }
    func updateCustomer(_ customer: Customer) async throws { customers[customer.phone] = customer }
    func deleteCustomer(phoneNumber: String) async throws {}
    func markAsDeleted(id: String) async throws {}
    func sync(force: Bool) async throws {}
}

struct RecordingAudit: AuditLogging {
    final class Box: @unchecked Sendable { var actions: [String] = [] }
    let box = Box()
    func log(_ category: AuditCategory, action: String, summary: String, targetId: String?) async {
        box.actions.append(action)
    }
}

struct SaleLifecycleRepositoryTests {

    private struct SUT {
        let lifecycle: SaleLifecycleRepository
        let sales: LifecycleSaleRepository
        let inventory: LifecycleInventoryRepository
        let customers: LifecycleCustomerRepository
        let movements: OrgCollectionRepository<StockMovement>
        let ledger: OrgCollectionRepository<CustomerLedgerEntry>
        let audit: RecordingAudit
    }

    private func makeSUT() throws -> SUT {
        let database = try SkipSqlDatabase(filepath: ":memory:")
        let context = FixedOrgContext(orgId: nil)
        let movements = OrgCollectionRepository<StockMovement>(storage: OrgCollectionLocalStorage(database: database),
                                                               service: OrgCollectionService(store: InMemoryStore()),
                                                               context: context, syncStorage: SyncStorage(db: database))
        let ledger = OrgCollectionRepository<CustomerLedgerEntry>(storage: OrgCollectionLocalStorage(database: database),
                                                                  service: OrgCollectionService(store: InMemoryStore()),
                                                                  context: context, syncStorage: SyncStorage(db: database))
        let sales = LifecycleSaleRepository()
        let inventory = LifecycleInventoryRepository()
        inventory.items["pen"] = InventoryItem(id: "pen", name: "Pen", currentStock: 10)
        let customers = LifecycleCustomerRepository()
        customers.customers["9"] = Customer(name: "Asha", phone: "9", createdAt: 0, lastPurchaseDate: nil, totalSales: 1,
                                            totalAmountSpent: 0, updatedAt: nil, isDeleted: false)
        let audit = RecordingAudit()
        let lifecycle = SaleLifecycleRepository(saleRepository: sales, inventoryRepository: inventory, customerRepository: customers,
                                                stockMovements: movements, ledger: ledger, audit: audit)
        return SUT(lifecycle: lifecycle, sales: sales, inventory: inventory, customers: customers,
                   movements: movements, ledger: ledger, audit: audit)
    }

    private func sale(qty: Int = 3, credit: Double = 0, at date: Date = Date()) -> Sale {
        let total = Double(qty) * 10
        var payments: [PaymentMode: Double] = [.cash: total - credit]
        if credit > 0 { payments[.credit] = credit }
        return Sale(id: "s1", staffId: "u1", customerPhone: "9", customerName: "Asha",
                    items: [SaleItem(categoryId: "pen", categoryName: "Pen", qty: qty, stickerPrice: 10, finalPrice: 10, discountType: .percentage)],
                    subtotal: total, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: total,
                    payments: payments, timestamp: date, source: "POS", status: "Completed", whatsappStatus: "unsent")
    }

    @Test func recordingASaleTakesStockAndAddsCreditDue() async throws {
        let sut = try makeSUT()
        let bill = sale(qty: 3, credit: 20)
        try await sut.sales.confirmSale(bill, heldBillId: nil)
        try await sut.lifecycle.recordEffects(of: bill, by: "u1")

        #expect(sut.inventory.items["pen"]?.currentStock == 7)
        #expect(try await sut.movements.all().first?.delta == -3)
        #expect(try await sut.ledger.all().first?.amount == 20)
        #expect(sut.customers.customers["9"]?.dueBalance == 20)
    }

    @Test func cancellingReversesStockAndDue() async throws {
        let sut = try makeSUT()
        let bill = sale(qty: 3, credit: 20)
        try await sut.sales.confirmSale(bill, heldBillId: nil)
        try await sut.lifecycle.recordEffects(of: bill, by: "u1")
        let cancelled = try await sut.lifecycle.cancel(saleId: "s1", reason: "Duplicate bill", by: "u1")

        #expect(cancelled.isCancelled)
        #expect(sut.inventory.items["pen"]?.currentStock == 10)
        #expect(sut.customers.customers["9"]?.dueBalance == 0)
        #expect(sut.audit.box.actions == ["bill.cancel"])
        await #expect(throws: SaleLifecycleError.alreadyCancelled) {
            try await sut.lifecycle.cancel(saleId: "s1", reason: "again", by: "u1")
        }
    }

    @Test func undoOnlyWithinFiveMinutes() async throws {
        let sut = try makeSUT()
        let bill = sale(at: Date().addingTimeInterval(-60))
        try await sut.sales.confirmSale(bill, heldBillId: nil)
        await #expect(throws: SaleLifecycleError.undoWindowPassed) {
            try await sut.lifecycle.undo(saleId: "s1", by: "u1", now: Date().addingTimeInterval(10 * 60))
        }
        let undone = try await sut.lifecycle.undo(saleId: "s1", by: "u1", now: Date())
        #expect(undone.cancelReason == "Undo")
        #expect(sut.audit.box.actions == ["bill.undo"])
    }

    @Test func storeCreditReturnPutsStockBackAndLowersDue() async throws {
        let sut = try makeSUT()
        let bill = sale(qty: 3, credit: 30)
        try await sut.sales.confirmSale(bill, heldBillId: nil)
        try await sut.lifecycle.recordEffects(of: bill, by: "u1")
        var returned = Sale(id: "r1", staffId: "u1", customerPhone: "9", customerName: "Asha",
                            items: [SaleItem(categoryId: "pen", categoryName: "Pen", qty: 1, stickerPrice: 10, finalPrice: 10, discountType: .percentage),
                                    SaleItem(categoryId: "custom-1", categoryName: "Misc", qty: 1, stickerPrice: 0, finalPrice: 0, discountType: .percentage)],
                            subtotal: 10, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 10,
                            payments: [.credit: 10], timestamp: Date(), source: "Return", status: "Completed", whatsappStatus: "unsent")
        returned.returnOfSaleId = "s1"
        try await sut.lifecycle.recordEffects(of: returned, by: "u1")

        #expect(sut.inventory.items["pen"]?.currentStock == 8)
        #expect(sut.customers.customers["9"]?.dueBalance == 20)
        #expect(try await sut.movements.all().allSatisfy { $0.itemId == "pen" })
    }

    @Test func editAdjustsStockByTheDifference() async throws {
        let sut = try makeSUT()
        let bill = sale(qty: 3)
        try await sut.sales.confirmSale(bill, heldBillId: nil)
        try await sut.lifecycle.recordEffects(of: bill, by: "u1")

        var edited = sale(qty: 1)
        edited.billNumber = "A-1"
        try await sut.lifecycle.edit(edited, reason: "Returned two", by: "u1")
        #expect(sut.inventory.items["pen"]?.currentStock == 9)
        #expect(sut.sales.sales["s1"]?.editReason == "Returned two")
        #expect(sut.audit.box.actions == ["bill.edit"])
    }
}
