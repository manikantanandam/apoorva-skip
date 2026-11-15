//
//  FirestoreStoring.swift
//  ApoorvaServices
//

import Foundation
import SkipFirebaseCore
import SkipFirebaseFirestore
import ManiLogger

private let logger = AppLogger(category: .network)

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
    /// Live updates for one document; yields nil while it doesn't exist.
    func listen(path: String) -> AsyncStream<StoreDocument?>
}

public extension FirestoreStoring {
    /// One-shot fallback for stores without real-time support (tests).
    func listen(path: String) -> AsyncStream<StoreDocument?> {
        AsyncStream { continuation in
            let task = Task {
                continuation.yield(try? await getDocument(path: path))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

#if os(Android)
private struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
}

/// Runs queued writes one at a time in the order they were enqueued, so an upsert followed by a soft delete
/// can't reach Firestore the other way round (independent `Task`s give no ordering guarantee).
private final class SerialWriteQueue: @unchecked Sendable {
    private let continuation: AsyncStream<@Sendable () async -> Void>.Continuation

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: (@Sendable () async -> Void).self)
        self.continuation = continuation
        Task {
            for await job in stream { await job() }
        }
    }

    func enqueue(_ job: @escaping @Sendable () async -> Void) {
        continuation.yield(job)
    }
}
#endif

private struct SendableListener: @unchecked Sendable {
    let value: ListenerRegistration
}

/// Values with special meaning to the store. Services use these so they don't import Firestore.
public enum StoreSentinel {
    /// Replaced by the server's commit time. Use for sync cursors — client clocks drift.
    public static let serverTimestamp = "__apoorva_server_timestamp__"
}

public final class FirebaseFirestoreStore: FirestoreStoring, @unchecked Sendable {
    private struct NotConfigured: Error {}

    /// Resolved on access, not at init. Throws instead of crashing when Firebase isn't configured (UI tests).
    private func database() throws -> Firestore {
        guard FirebaseApp.app() != nil else { throw NotConfigured() }
        return Firestore.firestore()
    }

    #if os(Android)
    private let writeQueue = SerialWriteQueue()
    #endif

    public init() {}

    public func getDocuments(collection path: String, query: StoreQuery) async throws -> [StoreDocument] {
        let collection = try database().collection(path)
        var firestoreQuery: Query = collection

        let filters = Self.filters(for: query)
        if !filters.isEmpty {
            firestoreQuery = collection.whereFilter(query.matchAny ? Filter.orFilter(filters) : Filter.andFilter(filters))
        }

        let snapshot = try await firestoreQuery.getDocuments()
        return snapshot.documents.map { StoreDocument(id: $0.documentID, data: $0.data()) }
    }

    public func getDocument(path: String) async throws -> StoreDocument? {
        let snapshot = try await database().document(path).getDocument()
        guard snapshot.exists else { return nil }
        return StoreDocument(id: snapshot.documentID, data: snapshot.data() ?? [:])
    }

    public func setData(_ data: [String: Any], path: String, merge: Bool) throws {
        #if os(Android)
        // skip-firebase's setData is async; hand it to the serial queue so calls return at once (the protocol's
        // offline-queued contract) while the writes still reach Firestore in call order.
        let write = UncheckedSendable(value: (try database().document(path), Self.resolvingSentinels(data)))
        writeQueue.enqueue {
            do { try await write.value.0.setData(write.value.1, merge: merge) } catch { logger.error("setData failed: \(error)") }
        }
        #else
        try database().document(path).setData(Self.resolvingSentinels(data), merge: merge)
        #endif
    }

    public func updateData(_ fields: [String: Any], path: String) async throws {
        try await database().document(path).updateData(Self.resolvingSentinels(fields))
    }

    public func listen(path: String) -> AsyncStream<StoreDocument?> {
        AsyncStream { continuation in
            guard let db = try? database() else {
                continuation.yield(nil)
                continuation.finish()
                return
            }
            let registration = db.document(path).addSnapshotListener { snapshot, _ in
                guard let snapshot else { return }
                continuation.yield(snapshot.exists ? StoreDocument(id: snapshot.documentID, data: snapshot.data() ?? [:]) : nil)
            }
            let listener = SendableListener(value: registration)
            continuation.onTermination = { _ in listener.value.remove() }
        }
    }

    static func filters(for query: StoreQuery) -> [Filter] {
        query.conditions.map { condition -> Filter in
            switch condition {
            case let .greaterThan(field, date):
                return Filter.whereField(field, isGreaterThan: Timestamp(date: date))
            case let .isIn(field, values):
                return Filter.whereField(field, in: values)
            case let .arrayContains(field, value):
                return Filter.whereField(field, arrayContains: value)
            }
        }
    }

    static func resolvingSentinels(_ data: [String: Any]) -> [String: Any] {
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
                logger.error("Failed to decode\(type): \(document.id) - \(error)")
            }
        }
        return records
    }

    func set<T: Encodable>(_ value: T, path: String, merge: Bool = false) throws {
        try setData(try Firestore.Encoder().encode(value), path: path, merge: merge)
    }
}
