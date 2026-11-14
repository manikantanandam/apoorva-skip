//
//  DocumentIDTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

struct DocumentIDTests {
    @Test func matchesFirestoreAutoIdShape() {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        for _ in 0..<100 {
            let id = DocumentID.make()
            #expect(id.count == 20)
            #expect(id.allSatisfy(allowed.contains))
        }
    }

    @Test func doesNotRepeat() {
        let ids = (0..<10_000).map { _ in DocumentID.make() }
        #expect(Set(ids).count == ids.count)
    }

    @Test func newModelsGetAutoIds() {
        #expect(InventoryItem(name: "Pen").id.count == 20)
        #expect(!InventoryItem(name: "Pen").id.contains("-"))
    }
}
