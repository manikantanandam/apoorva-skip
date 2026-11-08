//
//  OrgCollectionLocalStorage.swift
//  ApoorvaOfflineStorage
//

import Foundation
import ApoorvaModels
import SkipSQL

public protocol OrgCollectionStoring<Document>: Sendable {
    associatedtype Document: OrgDocument
    func all(includeDeleted: Bool) async throws -> [Document]
    func get(id: String) async throws -> Document?
    func upsert(_ document: Document) async throws
    func upsertAll(_ documents: [Document]) async throws
    func markDeleted(id: String) async throws
}

/// Local cache for any `OrgDocument` collection, backed by the shared `OrgDocument` table.
public final actor OrgCollectionLocalStorage<Document: OrgDocument>: OrgCollectionStoring {

    private let database: SkipSqlDatabase
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(database: SkipSqlDatabase) {
        self.database = database
    }

    public func all(includeDeleted: Bool = false) throws -> [Document] {
        let records = try database.context.fetchAll(
            OrgDocumentRecord.self,
            where: OrgDocumentRecord.collectionCol.equals(SQLValue(Document.collection))
        )
        return records
            .filter { includeDeleted || !$0.isDeleted }
            .compactMap { decode($0) }
    }

    public func get(id: String) throws -> Document? {
        guard let record = try database.context.fetch(
            OrgDocumentRecord.self,
            primaryKeys: [.text(Document.collection), .text(id)]
        ) else { return nil }
        return decode(record)
    }

    public func upsert(_ document: Document) throws {
        try database.context.insert(try record(for: document), upsert: true)
    }

    public func upsertAll(_ documents: [Document]) throws {
        guard !documents.isEmpty else { return }
        try database.context.transaction {
            for document in documents {
                try database.context.insert(try record(for: document), upsert: true)
            }
        }
    }

    public func markDeleted(id: String) throws {
        guard var document = try get(id: id) else { return }
        document.isDeleted = true
        document.updatedAt = Date()
        try upsert(document)
    }

    private func record(for document: Document) throws -> OrgDocumentRecord {
        let data = try encoder.encode(document)
        return OrgDocumentRecord(
            collection: Document.collection,
            id: document.id,
            payload: String(decoding: data, as: UTF8.self),
            updatedAt: document.updatedAt?.timeIntervalSince1970,
            isDeleted: document.isDeleted
        )
    }

    private func decode(_ record: OrgDocumentRecord) -> Document? {
        guard let data = record.payload.data(using: .utf8) else { return nil }
        return try? decoder.decode(Document.self, from: data)
    }
}
