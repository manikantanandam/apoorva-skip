//
//  BillsAndHomeTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaRepository
@testable import ApoorvaModules

private func bill(_ id: String, total: Double = 100, credit: Double = 0, daysAgo: Int = 0, cancelled: Bool = false,
                  customer: String = "Asha", item: String = "Pen", qty: Int = 1) -> Sale {
    var payments: [PaymentMode: Double] = [.cash: total - credit]
    if credit > 0 { payments[.credit] = credit }
    return Sale(id: id, staffId: "u1", customerPhone: "9\(id)", customerName: customer,
                items: [SaleItem(categoryId: item.lowercased(), categoryName: item, qty: qty, stickerPrice: total / Double(qty),
                                 finalPrice: total / Double(qty), discountType: .percentage)],
                subtotal: total, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: total,
                payments: payments, timestamp: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
                source: "POS", status: cancelled ? "Cancelled" : "Completed", whatsappStatus: "unsent", billNumber: "A-\(id)")
}

@MainActor
struct BillsViewModelTests {
    private func makeSUT(_ sales: [Sale]) async -> BillsViewModel {
        let repository = StubSaleRepository()
        repository.sales = sales
        let vm = BillsViewModel(repository: repository, memberRepository: StubOrgRepository<Member>())
        await vm.load()
        return vm
    }

    @Test func quickFiltersSelectTheRightBills() async {
        let vm = await makeSUT([bill("1"), bill("2", daysAgo: 1), bill("3", credit: 40, daysAgo: 3), bill("4", cancelled: true)])
        #expect(Set(vm.sales.map(\.id)) == ["1", "4"])
        vm.quick = .yesterday
        #expect(vm.sales.map(\.id) == ["2"])
        vm.quick = .unpaid
        #expect(vm.sales.map(\.id) == ["3"])
        vm.quick = .cancelled
        #expect(vm.sales.map(\.id) == ["4"])
    }

    @Test func todayTotalsIgnoreCancelledBills() async {
        let vm = await makeSUT([bill("1", total: 300), bill("2", total: 200, cancelled: true)])
        #expect(vm.todayTotal == 300)
        #expect(vm.todayCount == 1)
    }

    @Test func searchMatchesNameAndBillNumber() async {
        let vm = await makeSUT([bill("1", customer: "Ravi"), bill("2", customer: "Meena")])
        vm.searchText = "mee"
        #expect(vm.sales.map(\.id) == ["2"])
        vm.searchText = "A-1"
        #expect(vm.sales.map(\.id) == ["1"])
    }

    @Test func advancedFiltersCountAndApply() async {
        let vm = await makeSUT([bill("1"), bill("2", credit: 100), bill("3", daysAgo: 20)])
        var filters = BillFilters()
        filters.range = .all
        filters.modes = [.credit]
        #expect(vm.count(with: filters) == 1)
        vm.applyFilters(filters)
        #expect(vm.quick == nil)
        #expect(vm.sales.map(\.id) == ["2"])
    }
}

@MainActor
struct BillEditViewModelTests {
    final class NoopLifecycle: SaleLifecycleRepositoryProtocol, @unchecked Sendable {
        var edited: Sale?
        func recordEffects(of sale: Sale, by actorId: String) async throws {}
        func cancel(saleId: String, reason: String, by actorId: String) async throws -> Sale { throw SaleLifecycleError.notFound }
        func undo(saleId: String, by actorId: String, now: Date) async throws -> Sale { throw SaleLifecycleError.notFound }
        func edit(_ edited: Sale, reason: String, by actorId: String) async throws { self.edited = edited }
    }

    @Test func editingRecomputesTotalAndNeedsAReason() async {
        let repository = StubSaleRepository()
        repository.sales = [bill("1", total: 300, qty: 3)]
        let lifecycle = NoopLifecycle()
        let vm = BillEditViewModel(saleId: "1", repository: repository, lifecycle: lifecycle, actorId: "u1")
        await vm.load()
        let lineId = vm.lines[0].id
        vm.setQty(1, for: lineId)
        #expect(vm.newTotal == 100)
        #expect(!vm.canSave)
        vm.reason = "Customer returned two"
        #expect(vm.canSave)
        #expect(await vm.save())
        #expect(lifecycle.edited?.netPayable == 100)
        #expect(lifecycle.edited?.payments[.cash] == 100)
    }

    @Test func cannotRemoveEveryLine() async {
        let repository = StubSaleRepository()
        repository.sales = [bill("1", total: 100)]
        let vm = BillEditViewModel(saleId: "1", repository: repository, lifecycle: NoopLifecycle(), actorId: "u1")
        await vm.load()
        vm.setQty(0, for: vm.lines[0].id)
        vm.reason = "oops"
        #expect(!vm.canSave)
    }
}

@MainActor
struct HomeViewModelTests {
    private func makeSUT(vertical: Vertical, sales: [Sale], items: [InventoryItem] = [], customers: [Customer] = [])
    async -> HomeViewModel {
        var settings = OrgSettings()
        settings.profile.vertical = vertical
        let session = AppSession(settingsRepository: StubOrgRepository<OrgSettings>([settings]),
                                 storeRepository: StubOrgRepository<Store>(),
                                 memberRepository: StubOrgRepository<Member>(),
                                 saleRepository: StubSaleRepository(),
                                 developerTools: StubDeveloperTools())
        await session.configure(user: makeSessionUser(), platform: PlatformConfig())
        let saleRepository = StubSaleRepository()
        saleRepository.sales = sales
        let inventory = MockPOSInventoryRepository()
        inventory.items = items
        let customerRepository = StubCustomerRepository()
        customerRepository.customers = customers
        let vm = HomeViewModel(session: session, saleRepository: saleRepository, customerRepository: customerRepository,
                               inventoryRepository: inventory, dailyCashflowRepository: StubDailyCashflowRepository())
        await vm.load()
        return vm
    }

    @Test func kiranaShowsCashInHandAndDues() async {
        let dueCustomer = Customer(name: "Meena", phone: "1", createdAt: 0, lastPurchaseDate: nil, totalSales: 2,
                                   totalAmountSpent: 0, updatedAt: nil, isDeleted: false, dueBalance: 1120)
        let vm = await makeSUT(vertical: .kirana, sales: [bill("1", total: 640), bill("2", total: 200, daysAgo: 1)],
                               customers: [dueCustomer])
        #expect(vm.kpis.map(\.title) == ["Today's sales", "Bills", "Cash in hand", "Dues"])
        #expect(vm.kpis[0].value == "₹640")
        #expect(vm.kpis[2].value == "₹640")
        #expect(vm.kpis[3].value == "₹1,120")
    }

    @Test func fancyShowsTopItemAndLowStock() async {
        let items = [InventoryItem(id: "teddy", name: "Teddy", currentStock: 2), InventoryItem(id: "pen", name: "Pen", currentStock: 50)]
        let vm = await makeSUT(vertical: .fancy, sales: [bill("1", item: "Teddy", qty: 3), bill("2", item: "Pen")], items: items)
        #expect(vm.kpis[2].value == "Teddy")
        #expect(vm.kpis[3].value == "1 items")
        #expect(vm.lowStock.map(\.id) == ["teddy"])
    }

    @Test func firstRunGuideShowsUntilTheFirstBill() async {
        let empty = await makeSUT(vertical: .kirana, sales: [])
        #expect(empty.showsFirstRunGuide)
        #expect(empty.firstRunSteps.map(\.isDone) == [false, false, false])
        let busy = await makeSUT(vertical: .kirana, sales: [bill("1")])
        #expect(!busy.showsFirstRunGuide)
    }

    @Test func trendComparesWithSameDayLastWeek() {
        #expect(HomeViewModel.trendCaption(108, 100) == "+8% vs last week")
        #expect(HomeViewModel.trendCaption(50, 0) == nil)
    }
}
