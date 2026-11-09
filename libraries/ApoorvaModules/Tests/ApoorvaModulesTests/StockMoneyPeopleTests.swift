//
//  StockMoneyPeopleTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaRepository
@testable import ApoorvaModules

private func sale(_ id: String, total: Double, payments: [PaymentMode: Double]? = nil, daysAgo: Int = 0, staff: String = "u1",
                  lines: [SaleItem]? = nil, isReturn: Bool = false, phone: String = "") -> Sale {
    var sale = Sale(id: id, staffId: staff, customerPhone: phone, customerName: "C",
                    items: lines ?? [SaleItem(categoryId: "pen", categoryName: "Pen", qty: 1, stickerPrice: total, finalPrice: total, discountType: .percentage)],
                    subtotal: total, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: total,
                    payments: payments ?? [.cash: total],
                    timestamp: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
                    source: "POS", status: "Completed", whatsappStatus: "unsent")
    if isReturn { sale.returnOfSaleId = "orig" }
    return sale
}

final class StubStock: StockRepositoryProtocol, @unchecked Sendable {
    var purchases: [Purchase] = []
    func adjust(itemId: String, _ adjustment: StockAdjustment, reason: StockMovementReason, note: String?, by actorId: String) async throws -> InventoryItem {
        InventoryItem(id: itemId, name: "x")
    }
    func recordPurchase(_ purchase: Purchase, by actorId: String) async throws { purchases.append(purchase) }
    func paySupplier(_ supplier: Supplier, amount: Double, mode: String, by actorId: String) async throws {}
}

final class StubPeople: PeopleRepositoryProtocol, @unchecked Sendable {
    var marked: [AttendanceRecord] = []
    var paid: [SalaryPayment] = []
    let salaries: StubOrgRepository<SalaryPayment>
    init(salaries: StubOrgRepository<SalaryPayment>) { self.salaries = salaries }
    func mark(_ record: AttendanceRecord) async throws { marked.append(record) }
    func pay(_ payment: SalaryPayment) async throws { paid.append(payment); try await salaries.save(payment) }
}

@MainActor
struct MoneyMathTests {
    @Test func cashDayAddsSalesAndCashEntriesToOpening() {
        let cash = CashflowTransaction.PaymentMode.cash.accountId
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let summaries = [DailyCashflowSummary(date: yesterday, openingBalances: [], closingBalances: [AccountBalance(id: cash, name: "Cash", balance: 2000)],
                                              updatedAt: 0, locked: true)]
        let sales = [sale("1", total: 7450), sale("2", total: 500, payments: [.upi: 500]), sale("3", total: 100, isReturn: true)]
        let out = CashflowTransaction(timestamp: Date(), particulars: "Supplier", amount: 1000, transactionType: .debit, paymentMode: .cash,
                                      category: .inventory, fromAccountId: cash, toAccountId: "", timestampInMs: 0, updatedAtInMs: 0)
        let day = CashDay(date: Date(), summaries: summaries, sales: sales, transactions: [out])
        #expect(day.opening == 2000)
        #expect(day.cashSales == 7350)
        #expect(day.cashOut == 1000)
        #expect(day.expectedClosing == 8350)
        #expect(day.byMode[.upi] == 500)
    }

    @Test func metricsEstimateCostWhenMissing() {
        let items = [InventoryItem(id: "pen", name: "Pen")]
        var withCost = InventoryItem(id: "watch", name: "Watch")
        withCost.costPrice = 300
        let sales = [sale("1", total: 100),
                     sale("2", total: 500, lines: [SaleItem(categoryId: "watch", categoryName: "Watch", qty: 1, stickerPrice: 500, finalPrice: 500, discountType: .percentage)])]
        let metrics = ShopMetrics(sales: sales, items: items + [withCost],
                                  expenses: [Expense(title: "Tea", category: .tea, amount: 50, createdBy: "u")])
        #expect(metrics.revenue == 600)
        #expect(metrics.cost == 380)
        #expect(metrics.netProfit == 170)
        #expect(metrics.usesEstimatedCost)
        #expect(metrics.topItems.first?.name == "Watch")
    }
}

@MainActor
struct StockScreensTests {
    @Test func csvMatchesColumnsAndFlagsMissingPrices() {
        let csv = ItemCSV(text: "Item Name,Group,MRP,Qty\nTeddy,Toys,\"1,499\",3\nNo price,Toys,,4\n")
        #expect(csv.columns["name"] == 0)
        #expect(csv.columns["price"] == 2)
        #expect(csv.rows.first?.price == 1499)
        #expect(csv.rows.first?.stock == 3)
        #expect(csv.rows.filter(\.isReady).count == 1)
        #expect(csv.rows.last?.line == 3)
    }

    @Test func itemFormBuildsWarrantyAndVariants() {
        let vm = ItemFormViewModel(itemId: nil, inventoryRepository: MockPOSInventoryRepository(), categoryRepository: nil, audit: nil)
        vm.hasWarranty = true
        vm.warrantyValueText = "1"
        vm.warrantyUnit = .years
        #expect(vm.warrantyMonths == 12)
        vm.warrantyUnit = .days
        vm.warrantyValueText = "45"
        #expect(vm.warrantyMonths == 2)
        vm.hasVariants = true
        vm.sizesText = "2.2, 2.4"
        vm.coloursText = "Ruby"
        let item = InventoryItem(name: "Bangle", variantsJSON: vm.variantsJSON)
        #expect(ItemVariants.from(item)?.sizes == ["2.2", "2.4"])
        #expect(ItemVariants.from(item)?.colours.first?.name == "Ruby")
    }

    @Test func adjustComputesNewStock() async {
        let inventory = MockPOSInventoryRepository()
        inventory.items = [InventoryItem(id: "t", name: "Teddy", currentStock: 3)]
        let vm = StockAdjustViewModel(itemId: "t", inventoryRepository: inventory, stock: StubStock(), actorId: "u1")
        await vm.load()
        vm.quantityText = "24"
        #expect(vm.newStock == 27)
        vm.mode = .exact
        vm.quantityText = "3"
        #expect(!vm.canSave)
        vm.mode = .remove
        #expect(vm.newStock == 0)
    }

    @Test func reorderSuggestsQuantitiesAndBuildsMessage() async {
        let inventory = MockPOSInventoryRepository()
        var low = InventoryItem(id: "atta", name: "Atta", currentStock: 2)
        low.lowStockThreshold = 5
        inventory.items = [low, InventoryItem(id: "rice", name: "Rice", currentStock: 50)]
        let vm = ReorderViewModel(inventoryRepository: inventory,
                                  supplierRepository: StubOrgRepository<Supplier>([Supplier(id: "s", name: "Ramesh", phone: "9849011223")]),
                                  shopName: "Sri Lakshmi")
        await vm.load()
        #expect(vm.lines.map(\.item.id) == ["atta"])
        #expect(vm.lines.first?.quantity == 8)
        #expect(vm.message.contains("• Atta × 8"))
        #expect(vm.whatsAppURL?.absoluteString.contains("wa.me/919849011223") == true)
        #expect(vm.purchaseLines.first?.quantity == 8)
    }

    @Test func purchaseTotalsAndPartPayment() async {
        let stock = StubStock()
        let vm = PurchaseFormViewModel(supplierId: "s", prefill: [PurchaseLine(itemId: "a", itemName: "Atta", quantity: 10, unitCost: 240)],
                                       supplierRepository: StubOrgRepository<Supplier>([Supplier(id: "s", name: "Ramesh")]),
                                       purchaseRepository: StubOrgRepository<Purchase>(), inventoryRepository: MockPOSInventoryRepository(),
                                       stock: stock, actorId: "u1")
        await vm.load()
        vm.update("a", quantity: 20)
        #expect(vm.total == 4800)
        vm.payment = .partPaid
        vm.paidText = "800"
        #expect(vm.saveTitle == "Save · ₹4,000 on credit")
        let purchase = await vm.save()
        #expect(purchase?.number == "P-001")
        #expect(stock.purchases.first?.paid == 800)
    }
}

@MainActor
struct PeopleTests {
    @Test func attendanceTapCycles() async {
        let members = StubOrgRepository<Member>([Member(id: "m1", name: "Anu", role: .cashier)])
        let people = StubPeople(salaries: StubOrgRepository<SalaryPayment>())
        let vm = AttendanceViewModel(memberRepository: members, attendanceRepository: StubOrgRepository<AttendanceRecord>(), people: people, actorId: "u1")
        await vm.load()
        let anu = vm.staff[0]
        await vm.tap(anu)
        #expect(vm.record(for: anu)?.status == .present)
        #expect(vm.record(for: anu)?.inAt != nil)
        await vm.tap(anu)
        #expect(vm.record(for: anu)?.status == .half)
        #expect(vm.presentToday == 0)
    }

    @Test func salaryAddsCommissionAndTakesOffAdvancesAndHalfDays() async {
        var anu = Member(id: "m1", name: "Anu", role: .cashier)
        anu.baseSalary = 15000
        anu.commissionPercent = 10
        let service = SaleItem(categoryId: "facial", categoryName: "Facial", qty: 1, stickerPrice: 18400, finalPrice: 18400,
                               discountType: .percentage, doneByStaffId: "m1")
        let sales = StubSaleRepository()
        sales.sales = [sale("1", total: 18400, lines: [service])]
        let halfDay = AttendanceRecord(memberId: "m1", memberName: "Anu", day: Date(), status: .half, markedBy: "u1")
        let salaries = StubOrgRepository<SalaryPayment>([SalaryPayment(memberId: "m1", memberName: "Anu", month: SalaryPayment.monthKey(Date()),
                                                                        kind: .advance, amount: 2000, createdBy: "u1")])
        let people = StubPeople(salaries: salaries)
        let vm = SalaryViewModel(memberRepository: StubOrgRepository<Member>([anu]), attendanceRepository: StubOrgRepository<AttendanceRecord>([halfDay]),
                                 salaryRepository: salaries, saleRepository: sales, people: people, actorId: "u1")
        await vm.load()
        let row = vm.rows[0]
        #expect(row.commission == 1840)
        #expect(row.deductions == 250)
        #expect(row.payable == 15000 + 1840 - 2000 - 250)
        #expect(await vm.pay(row))
        #expect(people.paid.last?.kind == .salary)
        #expect(vm.rows[0].isPaid)
        #expect(vm.nextToPay == nil)
    }
}

@MainActor
struct InsightsTests {
    @Test func repeatRateAndStaffTotals() async {
        let sales = StubSaleRepository()
        sales.sales = [sale("1", total: 100, phone: "1"), sale("2", total: 200, phone: "1"), sale("3", total: 400, staff: "u2", phone: "2")]
        let vm = InsightsViewModel(saleRepository: sales, inventoryRepository: MockPOSInventoryRepository(), customerRepository: StubCustomerRepository(),
                                   memberRepository: StubOrgRepository<Member>([Member(id: "u2", name: "Pooja", role: .cashier)]),
                                   expenseRepository: StubOrgRepository<Expense>(), ledgerRepository: StubOrgRepository<CustomerLedgerEntry>(),
                                   shopName: "Shop")
        await vm.load()
        vm.period = .week
        #expect(vm.repeatRate == 0.5)
        #expect(vm.staffSales.first?.name == "Pooja")
        #expect(vm.csv(for: .sales).components(separatedBy: "\n").count == 2)
        #expect(vm.salesSeries.count == 7)
    }
}
