//
//  OrgCollectionService.swift
//  ApoorvaServices
//

import Foundation
import FirebaseFirestore
import ApoorvaModels

/// A page of remote documents plus the newest server commit time seen, used as the next sync cursor.
public struct OrgFetchResult<Document: OrgDocument>: Sendable {
    public let documents: [Document]
    public let latestServerUpdate: Date?

    public init(documents: [Document], latestServerUpdate: Date?) {
        self.documents = documents
        self.latestServerUpdate = latestServerUpdate
    }
}

public protocol OrgCollectionServicing<Document>: Sendable {
    associatedtype Document: OrgDocument
    /// All documents when `since` is nil, otherwise those committed after it.
    func fetch(since: Date?, orgId: String) async throws -> OrgFetchResult<Document>
    func upsert(_ document: Document, orgId: String) throws
    func softDelete(id: String, orgId: String) async throws
}

/// Reads and writes `organizations/{orgId}/{Document.collection}`. Every write stamps
/// `serverUpdatedAt`, and incremental fetches filter on it, so edits made offline still
/// reach other devices once they sync.
public final class OrgCollectionService<Document: OrgDocument>: OrgCollectionServicing, @unchecked Sendable {

    private let store: FirestoreStoring

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public func fetch(since: Date?, orgId: String) async throws -> OrgFetchResult<Document> {
        var query = StoreQuery.all
        if let since {
            query = StoreQuery(conditions: [.greaterThan(field: "serverUpdatedAt", date: since)])
        }
        let raw = try await store.getDocuments(collection: collectionPath(orgId), query: query)

        var documents: [Document] = []
        var latest: Date?
        for document in raw {
            var data = document.data
            if data["id"] == nil { data["id"] = document.id }
            let serverDate = Self.date(from: data["serverUpdatedAt"])
            data.removeValue(forKey: "serverUpdatedAt")
            do {
                documents.append(try Firestore.Decoder().decode(Document.self, from: data))
                if let serverDate, serverDate > (latest ?? .distantPast) { latest = serverDate }
            } catch {
                print("❌ Failed to decode \(Document.self) \(document.id): \(error)")
            }
        }
        return OrgFetchResult(documents: documents, latestServerUpdate: latest)
    }

    public func upsert(_ document: Document, orgId: String) throws {
        var stamped = document
        stamped.updatedAt = Date()
        var data = try Firestore.Encoder().encode(stamped)
        data["serverUpdatedAt"] = StoreSentinel.serverTimestamp
        try store.setData(data, path: documentPath(document.id, orgId: orgId), merge: true)
    }

    public func softDelete(id: String, orgId: String) async throws {
        try await store.updateData([
            "isDeleted": true,
            "updatedAt": Date(),
            "serverUpdatedAt": StoreSentinel.serverTimestamp
        ], path: documentPath(id, orgId: orgId))
    }

    private func collectionPath(_ orgId: String) -> String {
        String.orgPath(orgId, Document.collection)
    }

    private func documentPath(_ id: String, orgId: String) -> String {
        "\(collectionPath(orgId))/\(id)"
    }

    private static func date(from value: Any?) -> Date? {
        if let timestamp = value as? Timestamp { return timestamp.dateValue() }
        return value as? Date
    }
}
