//
//  OrgCollectionAndSaleWriteTests.swift
//  ApoorvaServices
//

import Testing
import Foundation
import FirebaseFirestore
import ApoorvaModels
@testable import ApoorvaServices

struct OrgCollectionServiceTests {

    private func entry(_ id: String) -> CustomerLedgerEntry {
        CustomerLedgerEntry(id: id, customerPhone: "9", customerName: "Asha", kind: .payment, amount: -100, createdBy: "u")
    }

    @Test func upsertWritesUnderOrgPathWithServerTimestamp() throws {
        let store = MockFirestoreStore()
        let sut = OrgCollectionService<CustomerLedgerEntry>(store: store)
        try sut.upsert(entry("e1"), orgId: "org")

        let write = try #require(store.writes.first)
        #expect(write.path == "organizations/org/customerLedger/e1")
        #expect(write.merge)
        #expect(write.data["serverUpdatedAt"] as? String == StoreSentinel.serverTimestamp)
        #expect(write.data["amount"] as? Double == -100)
    }

    @Test func fetchDecodesDocsAndReportsLatestServerUpdate() async throws {
        let store = MockFirestoreStore()
        var older = try Firestore.Encoder().encode(entry("a"))
        older["serverUpdatedAt"] = Timestamp(date: Date(timeIntervalSince1970: 100))
        var newer = try Firestore.Encoder().encode(entry("b"))
        newer["serverUpdatedAt"] = Timestamp(date: Date(timeIntervalSince1970: 200))
        store.documents["organizations/org/customerLedger/a"] = older
        store.documents["organizations/org/customerLedger/b"] = newer

        let sut = OrgCollectionService<CustomerLedgerEntry>(store: store)
        let all = try await sut.fetch(since: nil, orgId: "org")
        #expect(all.documents.count == 2)
        #expect(all.latestServerUpdate == Date(timeIntervalSince1970: 200))

        let delta = try await sut.fetch(since: Date(timeIntervalSince1970: 150), orgId: "org")
        #expect(delta.documents.map(\.id) == ["b"])
    }

    @Test func fetchFillsIdFromDocumentIdWhenMissing() async throws {
        let store = MockFirestoreStore()
        var data = try Firestore.Encoder().encode(entry("ignored"))
        data.removeValue(forKey: "id")
        store.documents["organizations/org/customerLedger/doc-7"] = data

        let result = try await OrgCollectionService<CustomerLedgerEntry>(store: store).fetch(since: nil, orgId: "org")
        #expect(result.documents.first?.id == "doc-7")
    }

    @Test func softDeleteFlagsDocument() async throws {
        let store = MockFirestoreStore()
        try await OrgCollectionService<CustomerLedgerEntry>(store: store).softDelete(id: "e1", orgId: "org")
        let update = try #require(store.updates.first)
        #expect(update.path == "organizations/org/customerLedger/e1")
        #expect(update.fields["isDeleted"] as? Bool == true)
    }
}

struct SaleWriteTests {

    private func sale() -> Sale {
        Sale(id: "s1", staffId: "u", customerPhone: "9", customerName: "Asha", items: [],
             subtotal: 100, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0,
             netPayable: 100, payments: [.cash: 60, .upi: 40], timestamp: Date(), source: "POS",
             status: "Completed", whatsappStatus: "unsent")
    }

    @Test func cancelWritesStatusAndReasonWithoutDeleting() async throws {
        let store = MockFirestoreStore()
        try await SaleService(store: store).updateSaleStatus(saleId: "s1", status: "Cancelled", reason: "Wrong items",
                                                            by: "u", at: Date(), for: "org")
        let update = try #require(store.updates.first)
        #expect(update.path == "organizations/org/sales/s1")
        #expect(update.fields["status"] as? String == "Cancelled")
        #expect(update.fields["cancelReason"] as? String == "Wrong items")
        #expect(update.fields["isDeleted"] == nil)
    }

    @Test func addSaleWritesPaymentsAsStringKeyedMap() async throws {
        let store = MockFirestoreStore()
        try await SaleService(store: store).addSale(sale(), for: "org")
        let write = try #require(store.writes.first)
        let payments = write.data["payments"] as? [String: Double]
        #expect(payments == ["cash": 60, "upi": 40])
        #expect(write.data["serverUpdatedAt"] as? String == StoreSentinel.serverTimestamp)
    }

    @Test func saleDecodesPaymentsFromFirestoreMap() async throws {
        let store = MockFirestoreStore()
        store.documents["organizations/org/sales/legacy"] = [
            "customerName": "Old", "netPayable": 50.0, "payments": ["cash": 50.0], "timestamp": Timestamp(date: Date())
        ]
        let sales = try await SaleService(store: store).getSales(for: "org")
        #expect(sales.first?.id == "legacy")
        #expect(sales.first?.payments[.cash] == 50)
    }
}
