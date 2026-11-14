//
//  StockMoneyPeople.swift
//  ApoorvaModels
//
//  Org collections for stock (categories, purchases, supplier ledger), money (expenses,
//  day close) and people (attendance, salary).
//

import Foundation

// MARK: - Stock

/// A billing category (design 77). Items point at it through `InventoryItem.categoryId`.
public struct ItemCategory: OrgDocument {
    public static let collection = "categories"

    public let id: String
    public var name: String
    public var sortOrder: Int
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = DocumentID.make(), name: String, sortOrder: Int, updatedAt: Date? = nil, isDeleted: Bool = false) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}

public struct PurchaseLine: Codable, Sendable, Hashable, Identifiable {
    public var id: String { itemId }
    public let itemId: String
    public let itemName: String
    public var quantity: Double
    public var unitCost: Double

    public init(itemId: String, itemName: String, quantity: Double, unitCost: Double) {
        self.itemId = itemId
        self.itemName = itemName
        self.quantity = quantity
        self.unitCost = unitCost
    }

    public var total: Double { (quantity * unitCost).rounded() }
}

/// A purchase from (or return to) a supplier (design 82).
public struct Purchase: OrgDocument {
    public static let collection = "purchases"

    public let id: String
    public let number: String
    public let supplierId: String
    public let supplierName: String
    public let isReturn: Bool
    /// Empty for "total only" purchases.
    public let lines: [PurchaseLine]
    public let total: Double
    public let paid: Double
    public let paidMode: String
    public let note: String
    public let createdAt: Date
    public let createdBy: String
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = DocumentID.make(), number: String, supplierId: String, supplierName: String, isReturn: Bool = false,
                lines: [PurchaseLine], total: Double, paid: Double, paidMode: String = PaymentMode.cash.rawValue, note: String = "",
                createdAt: Date = Date(), createdBy: String, updatedAt: Date? = nil, isDeleted: Bool = false) {
        self.id = id
        self.number = number
        self.supplierId = supplierId
        self.supplierName = supplierName
        self.isReturn = isReturn
        self.lines = lines
        self.total = total
        self.paid = paid
        self.paidMode = paidMode
        self.note = note
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    public var onCredit: Double { max(0, total - paid) }
}

public enum SupplierLedgerKind: String, Codable, Sendable, CaseIterable {
    case opening, purchase, payment, purchaseReturn
}

/// What the shop owes a supplier. `amount` is signed: positive means the shop owes more.
public struct SupplierLedgerEntry: OrgDocument {
    public static let collection = "supplierLedger"

    public let id: String
    public let supplierId: String
    public let kind: SupplierLedgerKind
    public let amount: Double
    public let mode: String?
    public let purchaseId: String?
    public let note: String
    public let createdAt: Date
    public let createdBy: String
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = DocumentID.make(), supplierId: String, kind: SupplierLedgerKind, amount: Double, mode: String? = nil,
                purchaseId: String? = nil, note: String = "", createdAt: Date = Date(), createdBy: String,
                updatedAt: Date? = nil, isDeleted: Bool = false) {
        self.id = id
        self.supplierId = supplierId
        self.kind = kind
        self.amount = amount
        self.mode = mode
        self.purchaseId = purchaseId
        self.note = note
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}

public extension Array where Element == SupplierLedgerEntry {
    /// Current amount owed to a supplier, including their opening due.
    func owed(to supplier: Supplier) -> Double {
        supplier.openingDue + filter { $0.supplierId == supplier.id && !$0.isDeleted && $0.kind != .opening }.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Money

public enum ExpenseCategory: String, Codable, Sendable, CaseIterable {
    case rent, salary, electricity, transport, repairs, supplier, tea, other

    public var title: String {
        switch self {
        case .rent: "Rent"
        case .salary: "Salary"
        case .electricity: "Electricity"
        case .transport: "Transport"
        case .repairs: "Repairs"
        case .supplier: "Supplier"
        case .tea: "Tea & snacks"
        case .other: "Other"
        }
    }
}

/// A shop expense (designs 87, 88). Saving one also writes a cash book debit.
public struct Expense: OrgDocument {
    public static let collection = "expenses"

    public let id: String
    public var title: String
    public var category: ExpenseCategory
    public var amount: Double
    /// "cash", "upi" or "bank".
    public var mode: String
    public var date: Date
    public var repeatsMonthly: Bool
    public var note: String
    public var createdBy: String
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = DocumentID.make(), title: String, category: ExpenseCategory, amount: Double, mode: String = "cash",
                date: Date = Date(), repeatsMonthly: Bool = false, note: String = "", createdBy: String,
                updatedAt: Date? = nil, isDeleted: Bool = false) {
        self.id = id
        self.title = title
        self.category = category
        self.amount = amount
        self.mode = mode
        self.date = date
        self.repeatsMonthly = repeatsMonthly
        self.note = note
        self.createdBy = createdBy
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}

/// The counted-cash close for one day (design 85). Keyed by the day ("dd-MM-yyyy").
public struct DayClose: OrgDocument {
    public static let collection = "dayCloses"

    public let id: String
    public let date: Date
    public let expectedCash: Double
    public let countedCash: Double
    public let note: String
    public let carryForward: Bool
    public let closedBy: String
    public let closedByName: String
    public let closedAt: Date
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(date: Date, expectedCash: Double, countedCash: Double, note: String, carryForward: Bool,
                closedBy: String, closedByName: String, closedAt: Date = Date(), updatedAt: Date? = nil, isDeleted: Bool = false) {
        self.id = date.dayKey
        self.date = Calendar.current.startOfDay(for: date)
        self.expectedCash = expectedCash
        self.countedCash = countedCash
        self.note = note
        self.carryForward = carryForward
        self.closedBy = closedBy
        self.closedByName = closedByName
        self.closedAt = closedAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    public var difference: Double { countedCash - expectedCash }
}

public extension Date {
    /// "dd-MM-yyyy", the id format daily cashflow summaries already use.
    var dayKey: String {
        let components = Calendar.current.dateComponents([.day, .month, .year], from: self)
        return String(format: "%02d-%02d-%04d", components.day ?? 0, components.month ?? 0, components.year ?? 0)
    }
}

// MARK: - People

public enum AttendanceStatus: String, Codable, Sendable, CaseIterable {
    case present, half, absent, leave

    public var title: String {
        switch self {
        case .present: "Present"
        case .half: "Half day"
        case .absent: "Absent"
        case .leave: "Leave"
        }
    }

    /// Tapping a row cycles present → half → absent → leave → present.
    public var next: AttendanceStatus {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// One person's attendance for one day (design 71). Id: "<dayKey>_<memberId>".
public struct AttendanceRecord: OrgDocument {
    public static let collection = "attendance"

    public let id: String
    public let memberId: String
    public let memberName: String
    public let day: Date
    public var status: AttendanceStatus
    public var inAt: Date?
    public var markedBy: String
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(memberId: String, memberName: String, day: Date, status: AttendanceStatus, inAt: Date? = nil, markedBy: String,
                updatedAt: Date? = nil, isDeleted: Bool = false) {
        self.id = "\(day.dayKey)_\(memberId)"
        self.memberId = memberId
        self.memberName = memberName
        self.day = Calendar.current.startOfDay(for: day)
        self.status = status
        self.inAt = inAt
        self.markedBy = markedBy
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}

public enum SalaryPaymentKind: String, Codable, Sendable { case salary, advance }

/// A salary payment or advance (design 72). Month is "yyyy-MM".
public struct SalaryPayment: OrgDocument {
    public static let collection = "salaryPayments"

    public let id: String
    public let memberId: String
    public let memberName: String
    public let month: String
    public let kind: SalaryPaymentKind
    public let amount: Double
    public let mode: String
    public let createdAt: Date
    public let createdBy: String
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = DocumentID.make(), memberId: String, memberName: String, month: String, kind: SalaryPaymentKind,
                amount: Double, mode: String = "cash", createdAt: Date = Date(), createdBy: String,
                updatedAt: Date? = nil, isDeleted: Bool = false) {
        self.id = id
        self.memberId = memberId
        self.memberName = memberName
        self.month = month
        self.kind = kind
        self.amount = amount
        self.mode = mode
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    public static func monthKey(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }
}
