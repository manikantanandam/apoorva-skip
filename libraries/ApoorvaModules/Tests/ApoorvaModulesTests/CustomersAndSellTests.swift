//
//  CustomersAndSellTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaRepository
@testable import ApoorvaModules

private func customer(_ name: String, phone: String, due: Double = 0, visits: Int = 0, lastVisitDaysAgo: Int? = nil,
                      createdDaysAgo: Int = 100, birthday: Date? = nil) -> Customer {
    let now = Date()
    return Customer(name: name, phone: phone, createdAt: now.addingTimeInterval(Double(-createdDaysAgo) * 86_400).timeIntervalSince1970,
                    lastPurchaseDate: lastVisitDaysAgo.map { now.addingTimeInterval(Double(-$0) * 86_400).timeIntervalSince1970 },
                    totalSales: visits, totalAmountSpent: 0, updatedAt: nil, isDeleted: false,
                    birthday: birthday?.timeIntervalSince1970, dueBalance: due)
}

final class StubDues: DuesRepositoryProtocol, @unchecked Sendable {
    var entries: [CustomerLedgerEntry] = []
    var collected: [(phone: String, amount: Double, mode: PaymentMode)] = []
    var cashIn: [Double] = []
    let customers: StubCustomerRepository

    init(customers: StubCustomerRepository) { self.customers = customers }

    func collect(phone: String, amount: Double, mode: PaymentMode, by actorId: String) async throws -> Customer {
        collected.append((phone, amount, mode))
        var customer = try await customers.getCustomer(phone: phone)!
        customer.dueBalance -= amount
        try await customers.updateCustomer(customer)
        return customer
    }
    func ledger(phone: String) async throws -> [CustomerLedgerEntry] { entries.filter { $0.customerPhone == phone } }
    func recordCashIn(amount: Double, mode: PaymentMode, particulars: String, person: String?, at date: Date) async throws {
        if amount > 0 && mode != .credit { cashIn.append(amount) }
    }
}

struct StubContacts: ContactsProviding {
    var granted = true
    var contacts: [PhoneContact]
    func requestAccess() async -> Bool { granted }
    func fetchContacts() async throws -> [PhoneContact] { contacts }
}

@MainActor
struct CustomerScreensTests {
    @Test func listFiltersAndTotals() async {
        let repository = StubCustomerRepository()
        repository.customers = [customer("Meena", phone: "1", due: 1120, visits: 9, lastVisitDaysAgo: 0),
                                customer("Ravi", phone: "2", due: 420, visits: 2, lastVisitDaysAgo: 2),
                                customer("Lakshmi", phone: "3", visits: 6, lastVisitDaysAgo: 7, createdDaysAgo: 0)]
        let vm = CustomerListViewModel(repository: repository)
        await vm.prepareDate()
        #expect(vm.subtitle == "3 customers · ₹1,540 due")
        vm.filter = .withDues
        #expect(vm.filteredCustomers.map(\.name) == ["Meena", "Ravi"])
        vm.filter = .regulars
        #expect(Set(vm.filteredCustomers.map(\.name)) == ["Meena", "Lakshmi"])
        vm.filter = .newThisMonth
        #expect(vm.filteredCustomers.map(\.name) == ["Lakshmi"])
    }

    @Test func statementSplitsOpeningBillsAndPayments() {
        let start = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let entries = [
            CustomerLedgerEntry(customerPhone: "1", customerName: "M", kind: .opening, amount: 800, createdAt: start.addingTimeInterval(-86_400), createdBy: "u"),
            CustomerLedgerEntry(customerPhone: "1", customerName: "M", kind: .sale, amount: 3240, createdAt: start.addingTimeInterval(86_400), createdBy: "u"),
            CustomerLedgerEntry(customerPhone: "1", customerName: "M", kind: .payment, amount: -2920, createdAt: start.addingTimeInterval(2 * 86_400), createdBy: "u")
        ]
        let statement = CustomerStatement(entries: entries, from: start, to: Date())
        #expect(statement.opening == 800)
        #expect(statement.bills == 3240)
        #expect(statement.payments == 2920)
        #expect(statement.closing == 1120)
        #expect(statement.entries.count == 2)
    }

    @Test func formValidatesAndRejectsDuplicates() async {
        let repository = StubCustomerRepository()
        repository.customers = [customer("Old", phone: "9701055443")]
        let vm = CustomerFormViewModel(phone: nil, repository: repository)
        vm.name = "Anitha Rao"
        vm.phone = "+91 97010 55443"
        #expect(vm.canSave)
        #expect(await vm.save() == nil)
        #expect(vm.errorMessage?.contains("already exists") == true)
        vm.phone = "97010 55444"
        vm.allowsCredit = true
        vm.creditLimitText = "2000"
        let saved = await vm.save()
        #expect(saved?.creditLimit == 2000)
        #expect(repository.customers.count == 2)
    }

    @Test func collectRecordsThroughDues() async {
        let repository = StubCustomerRepository()
        repository.customers = [customer("Meena", phone: "1", due: 1120)]
        let dues = StubDues(customers: repository)
        let vm = CollectDueViewModel(phone: "1", customerRepository: repository, dues: dues, actorId: "u1")
        await vm.load()
        #expect(vm.amountText == "1120")
        vm.amountText = "800"
        #expect(await vm.record())
        #expect(dues.collected.first?.amount == 800)
        #expect(dues.collected.first?.mode == .upi)
        #expect(vm.due == 320)
    }

    @Test func reminderMessageCarriesTheUPILink() async {
        let repository = StubCustomerRepository()
        repository.customers = [customer("Meena S", phone: "9848011223", due: 1120)]
        let vm = DueReminderViewModel(phone: "9848011223", customerRepository: repository, shopName: "Sri Lakshmi Stores",
                                      upiId: "sri.lakshmi@okaxis")
        await vm.load()
        #expect(vm.message.hasPrefix("Namaste Meena garu, your balance at Sri Lakshmi Stores is ₹1,120."))
        #expect(vm.message.contains("upi://pay"))
        #expect(vm.url?.absoluteString.hasPrefix("https://wa.me/919848011223") == true)
        vm.includesUPILink = false
        vm.channel = .sms
        #expect(!vm.message.contains("upi://"))
        #expect(vm.url?.scheme == "sms")
    }

    @Test func importSkipsExistingAndDuplicateNumbers() async {
        let repository = StubCustomerRepository()
        repository.customers = [customer("Bhaskar", phone: "9000211887")]
        let contacts = StubContacts(contacts: [
            PhoneContact(id: "a", name: "Anitha Rao", phone: "+91 97010 55443"),
            PhoneContact(id: "a2", name: "Anitha Rao", phone: "097010 55443"),
            PhoneContact(id: "b", name: "Bhaskar", phone: "90002 11887"),
            PhoneContact(id: "c", name: "Landline", phone: "040 2345")
        ])
        let vm = ImportContactsViewModel(provider: contacts, repository: repository)
        await vm.load()
        #expect(vm.contacts.map(\.phone) == ["9701055443"])
        #expect(await vm.importSelected() == 1)
        #expect(repository.customers.count == 2)
    }

    @Test func offersFindBirthdaysAndLapsedCustomers() async {
        let repository = StubCustomerRepository()
        repository.customers = [customer("Anjali", phone: "9876543210", visits: 14, lastVisitDaysAgo: 2, birthday: Date()),
                                customer("Harika", phone: "2", visits: 1, lastVisitDaysAgo: 45)]
        let vm = OffersViewModel(repository: repository, shopName: "Glow Studio")
        await vm.load()
        #expect(vm.birthdaysToday.map(\.name) == ["Anjali"])
        #expect(vm.recipients.map(\.name) == ["Anjali"])
        vm.audience = .lapsed
        #expect(vm.recipients.map(\.name) == ["Harika"])
        #expect(vm.wishURL(for: vm.birthdaysToday[0])?.absoluteString.contains("wa.me/919876543210") == true)
    }
}

@MainActor
struct SellScreensTests {
    @Test func savingAnOrderNumbersItBooksTheAdvanceAndAddsTheCustomer() async {
        let orders = StubOrgRepository<Order>()
        let customers = StubCustomerRepository()
        let dues = StubDues(customers: customers)
        let vm = OrderFormViewModel(orders: orders, customerRepository: customers, dues: dues, audit: nil, actorId: "u1", actorName: "Owner")
        vm.customerPhone = "98480 44556"
        vm.customerName = "Lavanya K"
        vm.details = "Custom haram"
        vm.totalText = "4500"
        vm.advanceText = "2000"
        #expect(vm.balance == 2500)
        let order = await vm.save()
        #expect(order?.number == "O-0001")
        #expect(order?.customerPhone == "9848044556")
        #expect(dues.cashIn == [2000])
        #expect(customers.customers.first?.name == "Lavanya K")
    }

    @Test func deliveringBillsTheBalanceThenClosesTheOrder() async {
        let order = Order(id: "o1", number: "O-0042", customerPhone: "1", customerName: "Lavanya", details: "Haram",
                          total: 4500, advance: 2000, readyBy: Date(), createdBy: "u1")
        let orders = StubOrgRepository<Order>([order])
        let vm = OrderDetailViewModel(orderId: "o1", repository: orders, audit: nil, shopName: "Swarna")
        await vm.load()
        await vm.markReady()
        #expect(orders.documents["o1"]?.status == .ready)
        let cart = vm.deliveryCart()!
        #expect(cart.totalPayable == 2500)
        let sale = Sale(id: "s1", staffId: "u1", customerPhone: "1", customerName: "Lavanya", items: cart.items.map(SaleItem.init(cartItem:)),
                        subtotal: 2500, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 2500,
                        payments: [.cash: 2500], timestamp: Date(), source: "POS", status: "Completed", whatsappStatus: "unsent")
        await OrderDeliveries.markDelivered(in: sale, repository: orders, audit: nil)
        #expect(orders.documents["o1"]?.status == .delivered)
        #expect(orders.documents["o1"]?.saleId == "s1")
    }

    @Test func warrantySearchAndClaim() async {
        let sold = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let old = Calendar.current.date(byAdding: .month, value: -14, to: Date())!
        let sales = StubSaleRepository()
        sales.sales = [
            Sale(id: "s1", staffId: "u1", customerPhone: "9848012345", customerName: "Ravi",
                 items: [SaleItem(categoryId: "watch", categoryName: "Kids Watch", qty: 1, stickerPrice: 600, finalPrice: 600, discountType: .percentage, warrantyMonths: 6),
                         SaleItem(categoryId: "pen", categoryName: "Pen", qty: 1, stickerPrice: 10, finalPrice: 10, discountType: .percentage)],
                 subtotal: 610, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 610,
                 payments: [.cash: 610], timestamp: sold, source: "POS", status: "Completed", whatsappStatus: "unsent", billNumber: "GG-311"),
            Sale(id: "s2", staffId: "u1", customerPhone: "9848012345", customerName: "Ravi",
                 items: [SaleItem(categoryId: "flask", categoryName: "Steel Flask", qty: 1, stickerPrice: 300, finalPrice: 300, discountType: .percentage, warrantyMonths: 12)],
                 subtotal: 300, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 300,
                 payments: [.cash: 300], timestamp: old, source: "POS", status: "Completed", whatsappStatus: "unsent", billNumber: "GG-188")
        ]
        let claims = StubOrgRepository<WarrantyClaim>()
        let vm = WarrantyViewModel(saleRepository: sales, claimRepository: claims, audit: nil, actorId: "u1")
        await vm.load()
        vm.query = "98480 12345"
        vm.search()
        #expect(vm.lines.map(\.item.categoryName) == ["Kids Watch", "Steel Flask"])
        #expect(vm.lines.map(\.isActive) == [true, false])
        vm.selected = vm.lines[0]
        vm.note = "Strap broken"
        #expect(await vm.recordClaim())
        #expect(vm.claims(for: vm.lines[0]).first?.action == .replace)
        vm.query = "GG-188"
        vm.search()
        #expect(vm.lines.count == 1)
        #expect(vm.selected == nil)
    }
}
