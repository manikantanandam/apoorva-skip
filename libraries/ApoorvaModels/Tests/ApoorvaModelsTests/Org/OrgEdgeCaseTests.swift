//
//  OrgEdgeCaseTests.swift
//  ApoorvaModels
//
//  Boundary cases for the Org/ models, sessions and permissions.
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("Org Edge Case Tests")
struct OrgEdgeCaseTests {

    private let cal = Calendar.current

    private func entry(_ amount: Double, at date: Date) -> CustomerLedgerEntry {
        CustomerLedgerEntry(customerPhone: "9", customerName: "A", kind: .adjustment, amount: amount, createdAt: date, createdBy: "u")
    }

    // MARK: - CustomerStatement

    @Test("Statement boundaries are inclusive at start and end, opening is strictly before start")
    func statementBoundaries() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)
        let statement = CustomerStatement(entries: [
            entry(10, at: Date(timeIntervalSince1970: 999)),
            entry(20, at: start),
            entry(30, at: end),
            entry(40, at: Date(timeIntervalSince1970: 2_001))
        ], from: start, to: end)
        #expect(statement.opening == 10)
        #expect(statement.bills == 50)
        #expect(statement.entries.count == 2)
        #expect(statement.closing == 60)
    }

    @Test("Statement of no entries is all zero")
    func statementEmpty() {
        let statement = CustomerStatement(entries: [], from: Date(), to: Date())
        #expect(statement.opening == 0)
        #expect(statement.bills == 0)
        #expect(statement.payments == 0)
        #expect(statement.closing == 0)
    }

    @Test("Statement sorts period entries oldest first and a zero amount counts as neither bill nor payment")
    func statementOrderAndZero() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 100)
        let late = entry(5, at: Date(timeIntervalSince1970: 50))
        let early = entry(0, at: Date(timeIntervalSince1970: 10))
        let statement = CustomerStatement(entries: [late, early], from: start, to: end)
        #expect(statement.entries.map(\.id) == [early.id, late.id])
        #expect(statement.bills == 5)
        #expect(statement.payments == 0)
    }

    @Test("Payments before the period reduce the opening balance")
    func statementNegativeOpening() {
        let statement = CustomerStatement(entries: [entry(-100, at: Date(timeIntervalSince1970: 1))],
                                          from: Date(timeIntervalSince1970: 10), to: Date(timeIntervalSince1970: 20))
        #expect(statement.opening == -100)
        #expect(statement.closing == -100)
    }

    // MARK: - Orders

    @Test("Order due today is not overdue, due before today is")
    func orderOverdueBoundary() {
        let startOfToday = cal.startOfDay(for: Date())
        let atStart = Order(number: "1", customerPhone: "9", customerName: "A", details: "d", total: 1, advance: 0,
                            readyBy: startOfToday, createdBy: "u")
        let justBefore = Order(number: "2", customerPhone: "9", customerName: "A", details: "d", total: 1, advance: 0,
                               readyBy: startOfToday.addingTimeInterval(-1), createdBy: "u")
        #expect(!atStart.isOverdue)
        #expect(justBefore.isOverdue)
    }

    @Test("Balance is zero when exactly paid and full when no advance")
    func orderBalanceBoundaries() {
        func make(total: Double, advance: Double) -> Order {
            Order(number: "1", customerPhone: "9", customerName: "A", details: "d", total: total, advance: advance,
                  readyBy: Date(), createdBy: "u")
        }
        #expect(make(total: 100, advance: 100).balance == 0)
        #expect(make(total: 100, advance: 0).balance == 100)
        #expect(make(total: 0, advance: 0).balance == 0)
    }

    // MARK: - Ledgers

    @Test("Ledger balance can go negative when overpaid")
    func ledgerNegative() {
        #expect([entry(100, at: Date()), entry(-150, at: Date())].balance == -50)
    }

    @Test("Supplier owed with no entries equals the opening due")
    func supplierOwedEmpty() {
        let supplier = Supplier(id: "s", name: "S", openingDue: 250)
        #expect([SupplierLedgerEntry]().owed(to: supplier) == 250)
    }

    @Test("Supplier owed can go negative when overpaid")
    func supplierOverpaid() {
        let supplier = Supplier(id: "s", name: "S", openingDue: 0)
        let entries = [SupplierLedgerEntry(supplierId: "s", kind: .payment, amount: -40, createdBy: "u")]
        #expect(entries.owed(to: supplier) == -40)
    }

    // MARK: - Packages

    @Test("Package with zero validity days expires at purchase time")
    func zeroValidity() {
        let purchased = Date(timeIntervalSinceNow: -60)
        let package = ServicePackage(name: "P", price: 1, sessions: 2, validityDays: 0)
        let bought = CustomerPackage(package: package, customerPhone: "9", customerName: "A", purchasedAt: purchased)
        #expect(bought.validUntil == purchased)
        #expect(bought.isExpired)
        #expect(!bought.isActive)
    }

    @Test("Membership with no session count has zero sessions left but stays active")
    func membershipSessions() {
        let package = ServicePackage(name: "M", price: 1, sessions: 0)
        let bought = CustomerPackage(package: package, customerPhone: "9", customerName: "A")
        #expect(bought.sessionsLeft == 0)
        #expect(bought.isActive)
    }

    // MARK: - Invite

    @Test("Explicit expiry overrides the 72 hour default and tokens differ between calls")
    func inviteExplicitExpiry() {
        let created = Date(timeIntervalSince1970: 0)
        let expires = Date(timeIntervalSince1970: 60)
        let invite = Invite(orgId: "o", orgName: "O", storeIds: [], storeName: "", role: .manager, name: "N", phone: "9",
                            invitedBy: "u", invitedByName: "U", createdAt: created, expiresAt: expires)
        #expect(invite.expiresAt == expires)
        #expect(invite.isExpired)
        #expect(Set((0..<20).map { _ in Invite.makeToken() }).count > 1)
    }

    // MARK: - Dates & people

    @Test("Day key zero-pads single digit day and month")
    func dayKeyPadding() {
        let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 9))!
        #expect(date.dayKey == "05-01-2026")
    }

    @Test("Month key rolls over at year boundaries")
    func monthKeyYearBoundary() {
        let dec = cal.date(from: DateComponents(year: 2025, month: 12, day: 31, hour: 12))!
        let jan = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        #expect(SalaryPayment.monthKey(dec) == "2025-12")
        #expect(SalaryPayment.monthKey(jan) == "2026-01")
    }

    @Test("Attendance and day close are keyed to the day regardless of time of day")
    func dayNormalisation() {
        let morning = cal.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 1))!
        let night = cal.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23))!
        let a = AttendanceRecord(memberId: "m", memberName: "M", day: morning, status: .present, markedBy: "u")
        let b = AttendanceRecord(memberId: "m", memberName: "M", day: night, status: .absent, markedBy: "u")
        #expect(a.id == b.id)
        #expect(a.day == b.day)
    }

    @Test("Day close with surplus cash has a positive difference and zero when balanced")
    func dayCloseDifference() {
        func close(expected: Double, counted: Double) -> DayClose {
            DayClose(date: Date(), expectedCash: expected, countedCash: counted, note: "", carryForward: false,
                     closedBy: "u", closedByName: "U")
        }
        #expect(close(expected: 100, counted: 120).difference == 20)
        #expect(close(expected: 100, counted: 100).difference == 0)
    }

    @Test("Purchase line total rounds half up and handles zero")
    func purchaseLineRounding() {
        #expect(PurchaseLine(itemId: "i", itemName: "n", quantity: 3, unitCost: 0.5).total == 2)
        #expect(PurchaseLine(itemId: "i", itemName: "n", quantity: 0, unitCost: 10).total == 0)
    }

    // MARK: - Session & permissions

    @Test("Org status matching is case-insensitive and only blocking statuses lock")
    func orgStatusCase() {
        let account = AuthAccount(uid: "u1", email: "a@b.com", isEmailVerified: true)
        let user = AppUser(id: "u1", name: "K", email: "a@b.com", role: .admin, status: "active", assignedOrgs: [],
                           createdAt: Date(), selectedOrganization: OrganizationSnapshot(orgId: "o1", name: "Shop"))
        func phase(_ status: String?) -> SessionPhase {
            SessionPhaseReducer.phase(account: account, profile: user, orgStatus: status, orgSettings: nil,
                                      minAppVersion: "0.0.0", appVersion: "1.0.0", requireEmailVerification: true)
        }
        #expect(phase("DELETED") == .blocked(status: "deleted"))
        #expect(phase("pending") == .ready(userId: "u1", orgId: "o1"))
        #expect(phase(nil) == .ready(userId: "u1", orgId: "o1"))
    }

    @Test("Running exactly the minimum version is not forced to update")
    func minVersionEqual() {
        let account = AuthAccount(uid: "u1", email: nil, isEmailVerified: false)
        let phase = SessionPhaseReducer.phase(account: account, profile: nil, orgStatus: nil, orgSettings: nil,
                                              minAppVersion: "1.0.0", appVersion: "1.0", requireEmailVerification: true)
        #expect(phase == .needsProfile(account))
    }

    @Test("Blocked org status is ignored while the user still has no org")
    func noOrgBeatsBlocked() {
        let account = AuthAccount(uid: "u1", email: "a@b.com", isEmailVerified: true)
        let user = AppUser(id: "u1", name: "K", email: "a@b.com", role: .standard, status: "active", assignedOrgs: [], createdAt: Date())
        let phase = SessionPhaseReducer.phase(account: account, profile: user, orgStatus: "blocked", orgSettings: nil,
                                              minAppVersion: "0.0.0", appVersion: "1.0.0", requireEmailVerification: true)
        #expect(phase == .needsOrgSetup(.chooseVertical))
    }

    @Test("AppVersion treats missing trailing parts as zero and handles empty strings")
    func appVersionEdges() {
        #expect(AppVersion("1.0") == AppVersion("1.0.0"))
        #expect(AppVersion("") == AppVersion("0"))
        #expect(AppVersion("1.0.1") > AppVersion("1.0"))
        #expect(AppVersion("10.0") > AppVersion("9.9.9"))
    }

    @Test("Grants for unknown roles or permissions never leak to other roles")
    func matrixIsolation() {
        let matrix = PermissionMatrix(grants: ["manager": ["cancelBill", "notAPermission"]])
        #expect(matrix.allows(.cancelBill, for: .manager))
        #expect(!matrix.allows(.cancelBill, for: .accountant))
        #expect(!matrix.allows(.cancelBill, for: .cashier))
    }

    @Test("Turning a permission on twice is idempotent")
    func matrixIdempotent() {
        var matrix = PermissionMatrix(grants: [:])
        matrix.set(.expenses, for: .manager, to: true)
        matrix.set(.expenses, for: .manager, to: true)
        #expect(matrix.grants["manager"] == ["expenses"])
    }
}
