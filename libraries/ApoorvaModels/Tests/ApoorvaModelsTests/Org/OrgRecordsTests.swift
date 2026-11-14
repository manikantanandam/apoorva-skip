//
//  OrgRecordsTests.swift
//  ApoorvaModels
//
//  AuditEvent, CustomerLedgerEntry, StockMovement, Supplier, ServicePackage, CustomerPackage.
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("Org Record Model Tests")
struct OrgRecordsTests {

    @Test("AuditEvent defaults updatedAt to createdAt")
    func auditEvent() {
        let created = Date(timeIntervalSince1970: 1_000)
        let event = AuditEvent(category: .security, action: "login", summary: "Signed in",
                               actorId: "u1", actorName: "Asha", createdAt: created)
        #expect(AuditEvent.collection == "auditEvents")
        #expect(event.updatedAt == created)
        #expect(event.targetId == nil)
        #expect(!event.isDeleted)
        #expect(AuditCategory.allCases.count == 7)
    }

    @Test("CustomerLedgerEntry defaults updatedAt to createdAt")
    func ledgerEntry() {
        let created = Date(timeIntervalSince1970: 2_000)
        let entry = CustomerLedgerEntry(customerPhone: "9", customerName: "Asha", kind: .sale,
                                        amount: 100, createdAt: created, createdBy: "u1")
        #expect(CustomerLedgerEntry.collection == "customerLedger")
        #expect(entry.updatedAt == created)
        #expect(LedgerEntryKind.allCases.count == 6)
    }

    @Test("Ledger balance sums signed amounts and skips deleted entries")
    func ledgerBalance() {
        func make(_ amount: Double, deleted: Bool = false) -> CustomerLedgerEntry {
            CustomerLedgerEntry(customerPhone: "9", customerName: "A", kind: .adjustment,
                                amount: amount, createdBy: "u", isDeleted: deleted)
        }
        #expect([make(500), make(-200), make(999, deleted: true)].balance == 300)
        #expect([CustomerLedgerEntry]().balance == 0)
    }

    @Test("StockMovement defaults updatedAt to createdAt and keeps signed delta")
    func stockMovement() {
        let created = Date(timeIntervalSince1970: 3_000)
        let movement = StockMovement(itemId: "i1", itemName: "Pen", delta: -3, reason: .sale,
                                     createdAt: created, createdBy: "u1")
        #expect(StockMovement.collection == "stockMovements")
        #expect(movement.delta == -3)
        #expect(movement.updatedAt == created)
        #expect(movement.refId == nil)
        #expect(StockMovementReason.allCases.count == 8)
    }

    @Test("Supplier defaults")
    func supplier() {
        let supplier = Supplier(name: "Sup")
        #expect(Supplier.collection == "suppliers")
        #expect(supplier.phone.isEmpty)
        #expect(supplier.openingDue == 0)
        #expect(supplier.notes.isEmpty)
        #expect(supplier.updatedAt == nil)
    }

    // MARK: - Packages

    private func makePackage(sessions: Int = 5, validityDays: Int = 90) -> ServicePackage {
        ServicePackage(name: "Glow Facial", price: 2500, sessions: sessions, validityDays: validityDays)
    }

    @Test("ServicePackage defaults")
    func servicePackage() {
        let package = ServicePackage(name: "Glow", price: 100, sessions: 3)
        #expect(ServicePackage.collection == "servicePackages")
        #expect(package.validityDays == 90)
        #expect(package.details.isEmpty)
    }

    @Test("CustomerPackage copies package fields and computes validUntil")
    func customerPackageInit() {
        let package = makePackage(validityDays: 30)
        let purchased = Date(timeIntervalSince1970: 1_700_000_000)
        let bought = CustomerPackage(package: package, customerPhone: "9", customerName: "Asha", purchasedAt: purchased)
        #expect(CustomerPackage.collection == "customerPackages")
        #expect(bought.packageId == package.id)
        #expect(bought.name == "Glow Facial")
        #expect(bought.price == 2500)
        #expect(bought.sessions == 5)
        #expect(bought.sessionsUsed == 0)
        #expect(bought.validUntil == Calendar.current.date(byAdding: .day, value: 30, to: purchased))
    }

    @Test("Sessions left never goes negative")
    func sessionsLeft() {
        var bought = CustomerPackage(package: makePackage(sessions: 5), customerPhone: "9", customerName: "A", sessionsUsed: 2)
        #expect(bought.sessionsLeft == 3)
        bought.sessionsUsed = 9
        #expect(bought.sessionsLeft == 0)
    }

    @Test("Package is active when unexpired and has sessions left, or is a membership")
    func packageActive() {
        let fresh = CustomerPackage(package: makePackage(sessions: 5), customerPhone: "9", customerName: "A")
        #expect(!fresh.isExpired)
        #expect(fresh.isActive)

        let used = CustomerPackage(package: makePackage(sessions: 5), customerPhone: "9", customerName: "A", sessionsUsed: 5)
        #expect(!used.isActive)

        let membership = CustomerPackage(package: makePackage(sessions: 0), customerPhone: "9", customerName: "A")
        #expect(membership.isActive)

        let longAgo = Date(timeIntervalSinceNow: -365 * 86_400)
        let expired = CustomerPackage(package: makePackage(sessions: 5, validityDays: 10), customerPhone: "9",
                                      customerName: "A", purchasedAt: longAgo)
        #expect(expired.isExpired)
        #expect(!expired.isActive)
    }
}
