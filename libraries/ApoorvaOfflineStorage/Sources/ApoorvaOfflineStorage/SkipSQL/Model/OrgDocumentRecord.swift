//
//  OrgDocumentRecord.swift
//  ApoorvaOfflineStorage
//

import Foundation
import ApoorvaUtilities
import SkipSQL

/// One row per cached org document, for every `OrgDocument` collection. The document
/// itself is stored as JSON so adding a collection (or a field) never needs a migration.
public struct OrgDocumentRecord: Sendable, Equatable {
    public let collection: String
    public let id: String
    public let payload: String
    public let updatedAt: Double?
    public let isDeleted: Bool

    public init(collection: String, id: String, payload: String, updatedAt: Double?, isDeleted: Bool) {
        self.collection = collection
        self.id = id
        self.payload = payload
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}

extension OrgDocumentRecord: SQLCodable {
    public static var table: SQLTable {
        SQLTable(name: "OrgDocument", columns: [collectionCol, idCol, payloadCol, updatedAtCol, isDeletedCol])
    }

    public init(row: SQLRow, context: SQLContext) throws {
        self.init(collection: try Self.collectionCol.textValueRequired(in: row),
                  id: try Self.idCol.textValueRequired(in: row),
                  payload: try Self.payloadCol.textValueRequired(in: row),
                  updatedAt: Self.updatedAtCol.realValue(in: row),
                  isDeleted: (Self.isDeletedCol.longValue(in: row) ?? 0).boolValue)
    }

    public func encode(row: inout SQLRow) throws {
        row[Self.collectionCol] = SQLValue(collection)
        row[Self.idCol] = SQLValue(id)
        row[Self.payloadCol] = SQLValue(payload)
        row[Self.updatedAtCol] = updatedAt.map { SQLValue($0) } ?? .null
        row[Self.isDeletedCol] = SQLValue(isDeleted.intValue)
    }

    public static let collectionCol = SQLColumn(name: "collection", type: .text, primaryKey: true)
    public static let idCol = SQLColumn(name: "id", type: .text, primaryKey: true)
    public static let payloadCol = SQLColumn(name: "payload", type: .text)
    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .real)
    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .long)
}
