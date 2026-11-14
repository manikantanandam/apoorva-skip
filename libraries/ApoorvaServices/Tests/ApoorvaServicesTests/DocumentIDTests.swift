//
//  DocumentIDTests.swift
//  ApoorvaServices
//

import Testing
import Foundation
import FirebaseFirestore
import ApoorvaModels
@testable import ApoorvaServices

/// Sale docs must keep the production shape: auto doc id stored again as `id`, lines keyed `cat_id` etc.
struct SaleDocumentShapeTests {
    private func sale(id: String = "0209aPrFedKKOIxk1npF") -> Sale {
        Sale(id: id, staffId: "8U6FwpPSKAeGCm0DoOo2awxh2QO2", customerPhone: "8247223175", customerName: "Keerthi",
             items: [SaleItem(categoryId: "LJLXlI5OuDPeDOWJtkTr", categoryName: "Earrings", qty: 1,
                              stickerPrice: 660, finalPrice: 528, discountType: .finalPrice)],
             subtotal: 660, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0,
             netPayable: 528, payments: [.cash: 528], timestamp: Date(), source: "POS",
             status: "Completed", whatsappStatus: "unsent")
    }

    @Test func addSaleStoresDocIdAsIdField() async throws {
        let store = MockFirestoreStore()
        try await SaleService(store: store).addSale(sale(), for: "org")
        let write = try #require(store.writes.first)
        #expect(write.path == "organizations/org/sales/0209aPrFedKKOIxk1npF")
        #expect(write.data["id"] as? String == "0209aPrFedKKOIxk1npF")
    }

    @Test func linesKeepProductionKeys() async throws {
        let store = MockFirestoreStore()
        try await SaleService(store: store).addSale(sale(), for: "org")
        let line = try #require((store.writes.first?.data["items"] as? [[String: Any]])?.first)
        #expect(Set(line.keys) == ["cat_id", "categoryName", "qty", "stickerPrice", "finalPrice", "discountType"])
        #expect(line["discountType"] as? String == "finalPrice")
    }

    @Test func updateSaleKeepsIdField() async throws {
        let store = MockFirestoreStore()
        try await SaleService(store: store).updateSale(sale(), for: "org")
        #expect(store.updates.first?.fields["id"] as? String == "0209aPrFedKKOIxk1npF")
    }

    /// Copied from a production sale doc (no billNumber/updatedAt/isDeleted/serverUpdatedAt).
    @Test func decodesProductionSale() async throws {
        let store = MockFirestoreStore()
        store.documents["organizations/org/sales/0209aPrFedKKOIxk1npF"] = [
            "customerName": "Keerthi", "customerPhone": "8247223175", "id": "0209aPrFedKKOIxk1npF",
            "items": [["cat_id": "LJLXlI5OuDPeDOWJtkTr", "categoryName": "Earrings", "discountType": "finalPrice",
                       "finalPrice": 528.0, "qty": 1, "stickerPrice": 660.0]],
            "netPayable": 1088.0, "overallDiscountAmount": 0.0, "overallDiscountPercent": 0.0,
            "payments": ["cash": 1088.0], "roundOff": 0.0, "source": "POS",
            "staffId": "8U6FwpPSKAeGCm0DoOo2awxh2QO2", "status": "Completed", "subtotal": 1360.0,
            "timestamp": Timestamp(date: Date()), "whatsappStatus": "unsent"
        ]
        let decoded = try #require(try await SaleService(store: store).getSales(for: "org").first)
        #expect(decoded.id == "0209aPrFedKKOIxk1npF")
        #expect(decoded.items.first?.categoryId == "LJLXlI5OuDPeDOWJtkTr")
        #expect(decoded.items.first?.discountType == .finalPrice)
        #expect(decoded.payments[.cash] == 1088)
        #expect(decoded.billNumber == nil)
        #expect(!decoded.isDeleted)
    }
}

struct DocumentIDBackfillTests {
    @Test func writesIdForEverySuppliedSaleIdWithoutReadingFirestore() async throws {
        let store = MockFirestoreStore()

        let result = try await DocumentIDBackfill(store: store).run(orgId: "org", saleIds: ["a", "b"])

        #expect(result == DocumentIDBackfillResult(written: 2))
        #expect(store.reads == 0)
        #expect(Set(store.writes.map(\.path)) == ["organizations/org/sales/a", "organizations/org/sales/b"])
        for write in store.writes {
            #expect(write.merge)
            #expect(write.data.count == 1)
            #expect(write.data["id"] as? String == String(write.path.split(separator: "/").last!))
        }
    }

    @Test func runningTwiceIsHarmless() async throws {
        let store = MockFirestoreStore()
        let backfill = DocumentIDBackfill(store: store)
        _ = try await backfill.run(orgId: "org", saleIds: ["a"])
        let again = try await backfill.run(orgId: "org", saleIds: ["a"])
        #expect(again == DocumentIDBackfillResult(written: 1))
        #expect(store.reads == 0)
    }
}
