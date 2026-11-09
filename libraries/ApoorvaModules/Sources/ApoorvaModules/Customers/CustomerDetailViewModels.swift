//
//  CustomerDetailViewModels.swift
//  ApoorvaModules
//
//  Customer detail & ledger (62), add/edit (64), collect (66), reminder (67), statement (68),
//  import contacts (65), wishes & offers (69).
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

/// Phone numbers as typed → 10-digit Indian mobile (drops +91 / leading 0).
enum PhoneNumber {
    static func normalize(_ text: String) -> String {
        var digits = text.filter(\.isNumber)
        if digits.count == 12, digits.hasPrefix("91") { digits.removeFirst(2) }
        if digits.count == 11, digits.hasPrefix("0") { digits.removeFirst() }
        return digits
    }

    static func whatsAppNumber(_ phone: String) -> String {
        let digits = normalize(phone)
        return digits.count == 10 ? "91" + digits : digits
    }
}

/// wa.me / sms: links shared by reminders, offers and orders.
public enum MessageLink {
    public static func whatsApp(to phone: String?, text: String) -> URL? {
        let number = phone.map(PhoneNumber.whatsAppNumber) ?? ""
        var components = URLComponents(string: "https://wa.me/\(number)")
        components?.queryItems = [URLQueryItem(name: "text", value: text)]
        return components?.url
    }

    public static func sms(to phone: String, text: String) -> URL? {
        var components = URLComponents(string: "sms:\(PhoneNumber.normalize(phone))")
        components?.queryItems = [URLQueryItem(name: "body", value: text)]
        return components?.url
    }
}

// MARK: - Detail (62)

@MainActor
@Observable
public final class CustomerDetailViewModel {
    public let phone: String
    public private(set) var customer: Customer?
    public private(set) var ledger: [CustomerLedgerEntry] = []
    public private(set) var bills: [Sale] = []

    private let customerRepository: CustomerRepositoryProtocol
    private let saleRepository: SaleRepositoryProtocol
    private let dues: DuesRepositoryProtocol

    public init(phone: String, customerRepository: CustomerRepositoryProtocol, saleRepository: SaleRepositoryProtocol,
                dues: DuesRepositoryProtocol) {
        self.phone = phone
        self.customerRepository = customerRepository
        self.saleRepository = saleRepository
        self.dues = dues
    }

    public func load() async {
        customer = try? await customerRepository.getCustomer(phone: phone)
        ledger = (try? await dues.ledger(phone: phone)) ?? []
        bills = ((try? await saleRepository.getSales()) ?? [])
            .filter { $0.customerPhone == phone && !$0.isCancelled }
            .sorted { $0.timestamp > $1.timestamp }
    }

    public var lifetime: Double {
        let fromBills = bills.reduce(0) { $0 + ($1.isReturn ? -$1.netPayable : $1.netPayable) }
        return max(fromBills, customer?.totalAmountSpent ?? 0)
    }

    public var visits: Int { max(bills.filter { !$0.isReturn }.count, customer?.totalSales ?? 0) }
    public var averageBill: Double { visits > 0 ? lifetime / Double(visits) : 0 }

    /// When the oldest still-unpaid credit started (approximate: the latest time the due was zero).
    public var dueSince: Date? {
        guard (customer?.dueBalance ?? 0) > 0 else { return nil }
        var running = 0.0
        var since: Date?
        for entry in ledger.reversed() {
            if running <= 0 && entry.amount > 0 { since = entry.createdAt }
            running += entry.amount
        }
        return since
    }

    public var since: String {
        guard let customer else { return "" }
        return Date(timeIntervalSince1970: customer.createdAt).formatted(.dateTime.month(.abbreviated).year())
    }

    /// Ledger rows, or bill rows when the customer has no ledger yet (legacy customers).
    public var rows: [(id: String, title: String, subtitle: String, amount: String, status: String?, isDue: Bool)] {
        if !ledger.isEmpty {
            return ledger.map { entry in
                let title: String
                switch entry.kind {
                case .sale: title = entry.note ?? "Bill"
                case .payment: title = "Payment · \((entry.mode ?? "cash").uppercased())"
                case .opening: title = "Opening balance"
                case .advance: title = entry.note ?? "Advance"
                case .reversal: title = entry.note ?? "Reversed"
                case .adjustment: title = entry.note ?? "Adjustment"
                }
                return (entry.id, title, entry.createdAt.shortDay,
                        (entry.amount >= 0 ? "+" : "−") + Money.format(abs(entry.amount)),
                        entry.amount > 0 ? "Due" : "Paid", entry.amount > 0)
            }
        }
        return bills.prefix(20).map { sale in
            ("bill-\(sale.id)", "Bill #\(sale.displayNumber)", "\(sale.timestamp.shortDay) · \(sale.primaryMode)",
             Money.format(sale.netPayable), sale.isDue ? "Due" : "Paid", sale.isDue)
        }
    }
}

// MARK: - Add / edit (64)

@MainActor
@Observable
public final class CustomerFormViewModel {
    public let isEditing: Bool
    public var name = ""
    public var phone = ""
    public var hasBirthday = false
    public var birthday = Date()
    public var notes = ""
    public var whatsappReceipts = true
    public var allowsCredit = false
    public var creditLimitText = "2000"
    public var isWholesale = false
    public var errorMessage: String?
    public var isSaving = false

    private var original: Customer?
    private let repository: CustomerRepositoryProtocol

    public init(phone: String?, repository: CustomerRepositoryProtocol) {
        self.isEditing = phone != nil
        self.phone = phone ?? ""
        self.repository = repository
    }

    public func load() async {
        guard isEditing, let customer = try? await repository.getCustomer(phone: phone) else { return }
        original = customer
        name = customer.name
        notes = customer.notes ?? ""
        whatsappReceipts = customer.whatsappReceipts
        allowsCredit = customer.creditLimit != nil
        creditLimitText = customer.creditLimit.map { String(Int($0)) } ?? "2000"
        isWholesale = customer.priceTier == "wholesale"
        if let birthday = customer.birthday {
            hasBirthday = true
            self.birthday = Date(timeIntervalSince1970: birthday)
        }
    }

    public var normalizedPhone: String { PhoneNumber.normalize(phone) }

    public var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && normalizedPhone.count == 10
    }

    public func save() async -> Customer? {
        guard canSave else {
            errorMessage = "Enter a name and a 10-digit phone number."
            return nil
        }
        isSaving = true
        defer { isSaving = false }
        if !isEditing, (try? await repository.getCustomer(phone: normalizedPhone)) != nil {
            errorMessage = "A customer with this phone already exists."
            return nil
        }
        let now = Date().timeIntervalSince1970
        var customer = original ?? Customer(name: "", phone: normalizedPhone, createdAt: now, lastPurchaseDate: nil,
                                            totalSales: 0, totalAmountSpent: 0, updatedAt: now, isDeleted: false)
        customer.name = name.trimmingCharacters(in: .whitespaces)
        customer.notes = notes.isEmpty ? nil : notes
        customer.whatsappReceipts = whatsappReceipts
        customer.creditLimit = allowsCredit ? (Double(creditLimitText) ?? 0) : nil
        customer.priceTier = isWholesale ? "wholesale" : nil
        customer.birthday = hasBirthday ? birthday.timeIntervalSince1970 : nil
        customer.updatedAt = now
        do {
            if isEditing {
                try await repository.updateCustomer(customer)
            } else {
                try await repository.saveCustomer(customer: customer)
            }
            return customer
        } catch {
            errorMessage = "Couldn't save. Try again."
            return nil
        }
    }
}

// MARK: - Collect (66)

@MainActor
@Observable
public final class CollectDueViewModel {
    public let phone: String
    public private(set) var customer: Customer?
    public var amountText = ""
    public var mode: PaymentMode = .upi
    public var isSaving = false
    public var errorMessage: String?

    private let customerRepository: CustomerRepositoryProtocol
    private let dues: DuesRepositoryProtocol
    private let actorId: String

    public init(phone: String, customerRepository: CustomerRepositoryProtocol, dues: DuesRepositoryProtocol, actorId: String) {
        self.phone = phone
        self.customerRepository = customerRepository
        self.dues = dues
        self.actorId = actorId
    }

    public func load() async {
        customer = try? await customerRepository.getCustomer(phone: phone)
        if amountText.isEmpty, let due = customer?.dueBalance, due > 0 { amountText = String(Int(due.rounded())) }
    }

    public var due: Double { customer?.dueBalance ?? 0 }
    public var amount: Double { Double(amountText) ?? 0 }
    public var canRecord: Bool { amount > 0 && customer != nil }

    public func record() async -> Bool {
        guard canRecord else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            customer = try await dues.collect(phone: phone, amount: amount, mode: mode, by: actorId)
            return true
        } catch {
            errorMessage = "Couldn't record the payment. Try again."
            return false
        }
    }
}

// MARK: - Reminder (67)

@MainActor
@Observable
public final class DueReminderViewModel {
    public enum Channel: String, CaseIterable, Sendable { case whatsApp = "WhatsApp", sms = "SMS" }

    public let phone: String
    public private(set) var customer: Customer?
    public var channel: Channel = .whatsApp
    public var includesUPILink = true

    private let customerRepository: CustomerRepositoryProtocol
    private let shopName: String
    private let upiId: String

    public init(phone: String, customerRepository: CustomerRepositoryProtocol, shopName: String, upiId: String) {
        self.phone = phone
        self.customerRepository = customerRepository
        self.shopName = shopName
        self.upiId = upiId
    }

    public func load() async {
        customer = try? await customerRepository.getCustomer(phone: phone)
    }

    public var canAddUPI: Bool { !upiId.isEmpty }

    public var message: String {
        guard let customer else { return "" }
        let firstName = customer.name.split(separator: " ").first.map(String.init) ?? customer.name
        var text = "Namaste \(firstName) garu, your balance at \(shopName) is \(Money.format(customer.dueBalance))."
        if includesUPILink && canAddUPI {
            text += " Pay by UPI: \(UPILink.pay(upiId: upiId, payee: shopName, amount: customer.dueBalance, note: "Balance"))"
        }
        return text + " Thank you!"
    }

    public var url: URL? {
        channel == .whatsApp ? MessageLink.whatsApp(to: phone, text: message) : MessageLink.sms(to: phone, text: message)
    }
}

// MARK: - Statement (68)

@MainActor
@Observable
public final class StatementViewModel {
    public enum Period: String, CaseIterable, Sendable {
        case thisMonth = "This month", lastThreeMonths = "Last 3 months", thisYear = "This year", custom = "Custom"
    }

    public let phone: String
    public private(set) var customer: Customer?
    public private(set) var entries: [CustomerLedgerEntry] = []
    public var period: Period = .thisMonth
    public var customStart = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    public var customEnd = Date()

    private let customerRepository: CustomerRepositoryProtocol
    private let dues: DuesRepositoryProtocol
    public let shopName: String

    public init(phone: String, customerRepository: CustomerRepositoryProtocol, dues: DuesRepositoryProtocol, shopName: String) {
        self.phone = phone
        self.customerRepository = customerRepository
        self.dues = dues
        self.shopName = shopName
    }

    public func load() async {
        customer = try? await customerRepository.getCustomer(phone: phone)
        entries = (try? await dues.ledger(phone: phone)) ?? []
    }

    public var range: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        switch period {
        case .thisMonth: return (calendar.dateInterval(of: .month, for: now)?.start ?? now, now)
        case .lastThreeMonths: return (calendar.date(byAdding: .month, value: -3, to: calendar.startOfDay(for: now)) ?? now, now)
        case .thisYear: return (calendar.dateInterval(of: .year, for: now)?.start ?? now, now)
        case .custom: return (calendar.startOfDay(for: customStart), calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEnd)) ?? customEnd)
        }
    }

    public var statement: CustomerStatement {
        CustomerStatement(entries: entries, from: range.start, to: range.end)
    }

    public var shareText: String {
        let s = statement
        var lines = ["*\(shopName)* · Statement for \(customer?.name ?? phone)",
                     "\(range.start.shortDay) – \(range.end.shortDay)",
                     "Opening balance: \(Money.format(s.opening))"]
        for entry in s.entries {
            lines.append("\(entry.createdAt.shortDay)  \(entry.note ?? entry.kind.rawValue.capitalized)  \(entry.amount >= 0 ? "+" : "−")\(Money.format(abs(entry.amount)))")
        }
        lines.append("Bills: +\(Money.format(s.bills))")
        lines.append("Payments: −\(Money.format(s.payments))")
        lines.append("Closing balance: \(Money.format(s.closing))")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Import contacts (65)

public struct PhoneContact: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let phone: String

    public init(id: String, name: String, phone: String) {
        self.id = id
        self.name = name
        self.phone = phone
    }
}

/// Reads the phone's contacts. iOS uses CNContactStore; tests use a stub.
public protocol ContactsProviding: Sendable {
    func requestAccess() async -> Bool
    func fetchContacts() async throws -> [PhoneContact]
}

@MainActor
@Observable
public final class ImportContactsViewModel {
    public private(set) var contacts: [PhoneContact] = []
    public var selected: Set<String> = []
    public var searchText = ""
    public private(set) var isDenied = false
    public private(set) var isImporting = false
    public var errorMessage: String?

    private let provider: ContactsProviding
    private let repository: CustomerRepositoryProtocol

    public init(provider: ContactsProviding, repository: CustomerRepositoryProtocol) {
        self.provider = provider
        self.repository = repository
    }

    /// Loads contacts with a valid mobile number that aren't customers yet, all selected.
    public func load() async {
        guard await provider.requestAccess() else {
            isDenied = true
            return
        }
        let existing = Set(((try? await repository.getCustomers()) ?? []).map(\.phone))
        var seen = Set<String>()
        contacts = ((try? await provider.fetchContacts()) ?? [])
            .compactMap { contact -> PhoneContact? in
                let phone = PhoneNumber.normalize(contact.phone)
                guard phone.count == 10, !existing.contains(phone), seen.insert(phone).inserted else { return nil }
                return PhoneContact(id: contact.id, name: contact.name, phone: phone)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        selected = Set(contacts.map(\.id))
    }

    public var visible: [PhoneContact] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.phone.contains(searchText) }
    }

    public func toggle(_ contact: PhoneContact) {
        if selected.contains(contact.id) { selected.remove(contact.id) } else { selected.insert(contact.id) }
    }

    /// Adds the selected contacts as customers. Returns how many were added.
    public func importSelected() async -> Int {
        isImporting = true
        defer { isImporting = false }
        let now = Date().timeIntervalSince1970
        var added = 0
        for contact in contacts where selected.contains(contact.id) {
            let customer = Customer(name: contact.name, phone: contact.phone, createdAt: now, lastPurchaseDate: nil,
                                    totalSales: 0, totalAmountSpent: 0, updatedAt: now, isDeleted: false)
            if (try? await repository.saveCustomer(customer: customer)) != nil { added += 1 }
        }
        if added < selected.count { errorMessage = "Added \(added) of \(selected.count). Try again for the rest." }
        return added
    }
}

// MARK: - Wishes & offers (69)

@MainActor
@Observable
public final class OffersViewModel {
    public enum Audience: String, CaseIterable, Sendable {
        case all = "All customers", regulars = "Regulars", lapsed = "Not visited 30 days", birthdaysThisMonth = "Birthdays this month"
    }

    public private(set) var customers: [Customer] = []
    public var audience: Audience = .regulars
    public var message: String

    private let repository: CustomerRepositoryProtocol
    private let shopName: String

    public init(repository: CustomerRepositoryProtocol, shopName: String) {
        self.repository = repository
        self.shopName = shopName
        self.message = "Special offer at \(shopName)! Visit us this week for exciting deals. – \(shopName)"
    }

    public func load() async {
        customers = ((try? await repository.getCustomers()) ?? []).filter { !$0.isDeleted }
    }

    private func birthdayComponents(_ customer: Customer) -> DateComponents? {
        customer.birthday.map { Calendar.current.dateComponents([.month, .day], from: Date(timeIntervalSince1970: $0)) }
    }

    public var birthdaysToday: [Customer] {
        let today = Calendar.current.dateComponents([.month, .day], from: Date())
        return customers.filter { birthdayComponents($0)?.month == today.month && birthdayComponents($0)?.day == today.day }
    }

    public var recipients: [Customer] {
        let month = Calendar.current.component(.month, from: Date())
        let cutoff = Date().addingTimeInterval(-30 * 86_400).timeIntervalSince1970
        switch audience {
        case .all: return customers
        case .regulars: return customers.filter(\.isRegular)
        case .lapsed: return customers.filter { ($0.lastPurchaseDate ?? 0) < cutoff && $0.lastPurchaseDate != nil }
        case .birthdaysThisMonth: return customers.filter { birthdayComponents($0)?.month == month }
        }
    }

    public func wishText(for customer: Customer) -> String {
        let firstName = customer.name.split(separator: " ").first.map(String.init) ?? customer.name
        return "Happy birthday \(firstName)! 🎉 Wishing you a wonderful year. Visit \(shopName) this week for a birthday treat."
    }

    /// One wa.me link per customer; WhatsApp has no bulk send, so the screen shares to a broadcast list instead.
    public func wishURL(for customer: Customer) -> URL? {
        MessageLink.whatsApp(to: customer.phone, text: wishText(for: customer))
    }
}
