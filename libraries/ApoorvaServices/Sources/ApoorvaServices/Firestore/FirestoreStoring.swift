//
//  FirestoreStoring.swift
//  ApoorvaServices
//

import Foundation
import FirebaseFirestore

/// Raw Firestore document: its id plus the untyped field map.
public struct StoreDocument: @unchecked Sendable {
    public let id: String
    public let data: [String: Any]

    public init(id: String, data: [String: Any]) {
        self.id = id
        self.data = data
    }
}

public enum StoreCondition: Sendable {
    case greaterThan(field: String, date: Date)
    case isIn(field: String, values: [String])
    case arrayContains(field: String, value: String)
}

public struct StoreQuery: Sendable {
    public var conditions: [StoreCondition]
    /// `true` combines the conditions with OR, `false` with AND.
    public var matchAny: Bool

    public init(conditions: [StoreCondition] = [], matchAny: Bool = false) {
        self.conditions = conditions
        self.matchAny = matchAny
    }

    public static let all = StoreQuery()
}

/// Thin seam over Firestore so services can be tested without a Firebase backend.
public protocol FirestoreStoring: Sendable {
    func getDocuments(collection path: String, query: StoreQuery) async throws -> [StoreDocument]
    /// Returns `nil` when the document does not exist.
    func getDocument(path: String) async throws -> StoreDocument?
    /// Not async on purpose: Firestore queues the write offline and only acknowledges it once online.
    func setData(_ data: [String: Any], path: String, merge: Bool) throws
    func updateData(_ fields: [String: Any], path: String) async throws
}

/// Values with special meaning to the store. Services use these so they don't import Firestore.
public enum StoreSentinel {
    /// Replaced by the server's commit time. Use for sync cursors — client clocks drift.
    public static let serverTimestamp = "__apoorva_server_timestamp__"
}

public final class FirebaseFirestoreStore: FirestoreStoring, @unchecked Sendable {
    private let db = Firestore.firestore()

    public init() {}

    public func getDocuments(collection path: String, query: StoreQuery) async throws -> [StoreDocument] {
        let collection = db.collection(path)
        var firestoreQuery: Query = collection

        let filters = query.conditions.map { condition -> Filter in
            switch condition {
            case let .greaterThan(field, date):
                return Filter.whereField(field, isGreaterThan: Timestamp(date: date))
            case let .isIn(field, values):
                return Filter.whereField(field, in: values)
            case let .arrayContains(field, value):
                return Filter.whereField(field, arrayContains: value)
            }
        }
        if !filters.isEmpty {
            firestoreQuery = collection.whereFilter(query.matchAny ? Filter.orFilter(filters) : Filter.andFilter(filters))
        }

        let snapshot = try await firestoreQuery.getDocuments()
        return snapshot.documents.map { StoreDocument(id: $0.documentID, data: $0.data()) }
    }

    public func getDocument(path: String) async throws -> StoreDocument? {
        let snapshot = try await db.document(path).getDocument()
        guard snapshot.exists else { return nil }
        return StoreDocument(id: snapshot.documentID, data: snapshot.data() ?? [:])
    }

    public func setData(_ data: [String: Any], path: String, merge: Bool) throws {
        db.document(path).setData(Self.resolvingSentinels(data), merge: merge)
    }

    public func updateData(_ fields: [String: Any], path: String) async throws {
        try await db.document(path).updateData(Self.resolvingSentinels(fields))
    }

    private static func resolvingSentinels(_ data: [String: Any]) -> [String: Any] {
        data.mapValues { value in
            if let string = value as? String, string == StoreSentinel.serverTimestamp {
                return FieldValue.serverTimestamp()
            }
            return value
        }
    }
}

extension FirestoreStoring {
    /// Decodes every document in the collection, skipping (and logging) the ones that fail.
    func fetch<T: Decodable>(_ type: T.Type, collection path: String, query: StoreQuery = .all) async throws -> [T] {
        let documents = try await getDocuments(collection: path, query: query)
        var records: [T] = []
        for document in documents {
            do {
                // Legacy docs don't store their own id as a field; fall back to the doc ID.
                var data = document.data
                if data["id"] == nil {
                    data["id"] = document.id
                }
                records.append(try Firestore.Decoder().decode(type, from: data))
            } catch {
                print("❌ Failed to decode \(type): \(document.id) - \(error)")
            }
        }
        return records
    }

    func set<T: Encodable>(_ value: T, path: String, merge: Bool = false) throws {
        try setData(try Firestore.Encoder().encode(value), path: path, merge: merge)
    }
}
