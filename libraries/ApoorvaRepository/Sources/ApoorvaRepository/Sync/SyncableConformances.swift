//
//  SyncableConformances.swift
//  ApoorvaRepository
//

import Foundation

/// How many of a collection's local changes haven't reached the server yet, for the Sync status screen.
public protocol PendingWritesReporting: Sendable {
    func pendingWriteCount() async -> Int
}

/// Lets repositories that only expose `sync(force:)` through their own protocol join the `SyncEngine`.
public struct SyncAdapter: SyncableRepository, PendingWritesReporting {
    public let syncKey: String
    private let run: @Sendable (Bool) async throws -> Void
    private let pendingWrites: @Sendable () async -> Int

    public init(_ syncKey: String,
                pendingWrites: @escaping @Sendable () async -> Int = { 0 },
                run: @escaping @Sendable (Bool) async throws -> Void) {
        self.syncKey = syncKey
        self.pendingWrites = pendingWrites
        self.run = run
    }

    public func sync(force: Bool) async throws {
        try await run(force)
    }

    public func pendingWriteCount() async -> Int {
        await pendingWrites()
    }
}
