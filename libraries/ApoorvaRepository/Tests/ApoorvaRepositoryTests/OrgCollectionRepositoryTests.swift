//
//  OrgCollectionRepositoryTests.swift
//  ApoorvaRepository
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaOfflineStorage
@testable import ApoorvaServices
@testable import ApoorvaRepository

/// Minimal in-memory `FirestoreStoring` for repository tests.
final class InMemoryStore: FirestoreStoring, @unchecked Sendable {
    var documents: [String: [String: Any]] = [:]
    var setCount = 0

    func getDocuments(collection path: String, query: StoreQuery) async throws -> [StoreDocument] {
        documents
            .filter { key, _ in key.hasPrefix(path + "/") && !key.dropFirst(path.count + 1).contains("/") }
            .map { StoreDocument(id: String($0.key.split(separator: "/").last ?? ""), data: $0.value) }
    }

    func getDocument(path: String) async throws -> StoreDocument? {
        documents[path].map { StoreDocument(id: path, data: $0) }
    }

    func setData(_ data: [String: Any], path: String, merge: Bool) throws {
        setCount += 1
        documents[path] = data.filter { ($0.value as? String) != StoreSentinel.serverTimestamp }
    }

    func updateData(_ fields: [String: Any], path: String) async throws {
        var existing = documents[path] ?? [:]
        for (key, value) in fields where (value as? String) != StoreSentinel.serverTimestamp {
            existing[key] = value
        }
        documents[path] = existing
    }
}

struct FixedOrgContext: OrgContextProviding {
    var orgId: String?
    func currentOrgId() async throws -> String? { orgId }
    func currentActor() async throws -> (id: String, name: String) { ("u1", "Kiran") }
}

struct OrgCollectionRepositoryTests {

    private func makeSUT(orgId: String? = "org") throws -> (OrgCollectionRepository<CustomerLedgerEntry>, InMemoryStore, SkipSqlDatabase) {
        let database = try SkipSqlDatabase(filepath: ":memory:")
        let store = InMemoryStore()
        let sut = OrgCollectionRepository<CustomerLedgerEntry>(
            storage: OrgCollectionLocalStorage(database: database),
            service: OrgCollectionService(store: store),
            context: FixedOrgContext(orgId: orgId),
            syncStorage: SyncStorage(db: database)
        )
        return (sut, store, database)
    }

    private func entry(_ id: String, amount: Double = 100) -> CustomerLedgerEntry {
        CustomerLedgerEntry(id: id, customerPhone: "9", customerName: "Asha", kind: .sale, amount: amount, createdBy: "u1")
    }

    @Test func saveWritesLocallyThenRemotely() async throws {
        let (sut, store, _) = try makeSUT()
        try await sut.save(entry("a"))
        #expect(try await sut.all().map(\.id) == ["a"])
        #expect(store.documents["organizations/org/customerLedger/a"] != nil)
    }

    @Test func saveWithoutOrgStaysLocal() async throws {
        let (sut, store, _) = try makeSUT(orgId: nil)
        try await sut.save(entry("a"))
        #expect(try await sut.all().count == 1)
        #expect(store.setCount == 0)
    }

    @Test func syncPullsRemoteDocuments() async throws {
        let (sut, store, _) = try makeSUT()
        let remote = OrgCollectionService<CustomerLedgerEntry>(store: store)
        try remote.upsert(entry("r1", amount: 40), orgId: "org")
        try remote.upsert(entry("r2", amount: 60), orgId: "org")

        try await sut.sync(force: true)
        #expect(Set(try await sut.all().map(\.id)) == ["r1", "r2"])
    }

    @Test func deleteHidesLocallyAndFlagsRemote() async throws {
        let (sut, store, _) = try makeSUT()
        try await sut.save(entry("a"))
        try await sut.delete(id: "a")
        #expect(try await sut.all().isEmpty)
        #expect(store.documents["organizations/org/customerLedger/a"]?["isDeleted"] as? Bool == true)
    }

    @Test func changesStreamFiresOnSave() async throws {
        let (sut, _, _) = try makeSUT()
        let stream = await sut.changes()
        try await sut.save(entry("a"))
        var iterator = stream.makeAsyncIterator()
        let fired: Void? = await iterator.next()
        #expect(fired != nil)
    }

    @Test func auditLoggerRecordsActor() async throws {
        let (repository, _, _) = try {
            let database = try SkipSqlDatabase(filepath: ":memory:")
            let repo = OrgCollectionRepository<AuditEvent>(
                storage: OrgCollectionLocalStorage(database: database),
                service: OrgCollectionService(store: InMemoryStore()),
                context: FixedOrgContext(orgId: "org"),
                syncStorage: SyncStorage(db: database)
            )
            return (repo, 0, 0)
        }()
        let logger = AuditLogger(repository: repository, context: FixedOrgContext(orgId: "org"))
        await logger.log(.bills, action: "bill.cancel", summary: "Cancelled #A-1", targetId: "s1")
        let events = try await repository.all()
        #expect(events.first?.actorName == "Kiran")
        #expect(events.first?.category == .bills)
    }
}

struct SyncEngineTests {

    final class CountingRepository: SyncableRepository, @unchecked Sendable {
        let syncKey: String
        let shouldFail: Bool
        var count = 0
        init(_ key: String, fail: Bool = false) { syncKey = key; shouldFail = fail }
        func sync(force: Bool) async throws {
            count += 1
            if shouldFail { throw NSError(domain: "test", code: 1) }
        }
    }

    @Test func syncAllRunsEveryRepositoryEvenIfOneFails() async {
        let engine = SyncEngine()
        let ok = CountingRepository("ok")
        let bad = CountingRepository("bad", fail: true)
        await engine.register([ok, bad])
        let statuses = await engine.syncAll()
        #expect(ok.count == 1)
        #expect(bad.count == 1)
        #expect(statuses.first { $0.key == "ok" }?.lastError == nil)
        #expect(statuses.first { $0.key == "bad" }?.lastError != nil)
        #expect(await engine.failedCount == 1)
    }

    @Test func registeringTheSameKeyTwiceIsIgnored() async {
        let engine = SyncEngine()
        await engine.register(CountingRepository("same"))
        await engine.register(CountingRepository("same"))
        #expect(await engine.allStatuses().count == 1)
    }
}
