//
//  OrgCollectionRepository.swift
//  ApoorvaRepository
//

import Foundation
import ApoorvaModels
import ApoorvaOfflineStorage
import ApoorvaServices

/// Who is signed in and which org/store they're working in, without re-fetching the user per call.
public protocol OrgContextProviding: Sendable {
    func currentOrgId() async throws -> String?
    func currentActor() async throws -> (id: String, name: String)
}

/// Default context backed by the cached current user.
public struct UserRepositoryOrgContext: OrgContextProviding {
    private let userRepository: UserRepositoryProtocol

    public init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }

    public func currentOrgId() async throws -> String? {
        try await userRepository.getCurrentUser().selectedOrganization?.orgId
    }

    public func currentActor() async throws -> (id: String, name: String) {
        let user = try await userRepository.getCurrentUser()
        return (user.id, user.name)
    }
}

/// Anything the `SyncEngine` can pull down.
public protocol SyncableRepository: Sendable {
    var syncKey: String { get }
    func sync(force: Bool) async throws
}

public protocol OrgCollectionRepositoryProtocol<Document>: SyncableRepository {
    associatedtype Document: OrgDocument
    func all() async throws -> [Document]
    func get(id: String) async throws -> Document?
    func save(_ document: Document) async throws
    func saveAll(_ documents: [Document]) async throws
    func delete(id: String) async throws
    func changes() async -> AsyncStream<Void>
}

/// Local-first repository for any `OrgDocument` collection. Writes land in SQLite first (so
/// the UI updates immediately and works offline), then go to Firestore, whose SDK queues
/// them until the device is back online.
public final actor OrgCollectionRepository<Document: OrgDocument>: OrgCollectionRepositoryProtocol {

    private let storage: OrgCollectionLocalStorage<Document>
    private let service: OrgCollectionService<Document>
    private let context: OrgContextProviding
    private let syncStorage: SyncStorage
    private var observers: [UUID: AsyncStream<Void>.Continuation] = [:]

    public nonisolated var syncKey: String { "org." + Document.collection }

    public init(storage: OrgCollectionLocalStorage<Document>,
                service: OrgCollectionService<Document>,
                context: OrgContextProviding,
                syncStorage: SyncStorage) {
        self.storage = storage
        self.service = service
        self.context = context
        self.syncStorage = syncStorage
    }

    public func all() async throws -> [Document] {
        try await storage.all(includeDeleted: false)
    }

    public func get(id: String) async throws -> Document? {
        try await storage.get(id: id)
    }

    public func save(_ document: Document) async throws {
        var stamped = document
        stamped.updatedAt = Date()
        try await storage.upsert(stamped)
        notify()
        if let orgId = try await context.currentOrgId() {
            try service.upsert(stamped, orgId: orgId)
        }
    }

    public func saveAll(_ documents: [Document]) async throws {
        guard !documents.isEmpty else { return }
        let now = Date()
        let stamped = documents.map { document -> Document in
            var copy = document
            copy.updatedAt = now
            return copy
        }
        try await storage.upsertAll(stamped)
        notify()
        if let orgId = try await context.currentOrgId() {
            for document in stamped {
                try service.upsert(document, orgId: orgId)
            }
        }
    }

    public func delete(id: String) async throws {
        try await storage.markDeleted(id: id)
        notify()
        if let orgId = try await context.currentOrgId() {
            try await service.softDelete(id: id, orgId: orgId)
        }
    }

    public func sync(force: Bool) async throws {
        guard let orgId = try await context.currentOrgId() else { return }
        let stored = force ? nil : (try? await syncStorage.getLastSyncTimestamp(for: syncKey))
        let result = try await service.fetch(since: stored.map(SyncCursor.queryStart(from:)), orgId: orgId)
        try await storage.upsertAll(result.documents)
        if let latest = result.latestServerUpdate {
            try await syncStorage.updateSyncTimestamp(for: syncKey, timestamp: latest.timeIntervalSince1970)
        }
        if !result.documents.isEmpty { notify() }
    }

    /// Emits whenever the local copy changes (local write or sync), so list screens can reload.
    public func changes() -> AsyncStream<Void> {
        let id = UUID()
        return AsyncStream { continuation in
            observers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeObserver(id) }
            }
        }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    private func notify() {
        for continuation in observers.values {
            continuation.yield()
        }
    }
}
