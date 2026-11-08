//
//  SyncableConformances.swift
//  ApoorvaRepository
//

import Foundation

/// Lets repositories that only expose `sync(force:)` through their own protocol join the `SyncEngine`.
public struct SyncAdapter: SyncableRepository {
    public let syncKey: String
    private let run: @Sendable (Bool) async throws -> Void

    public init(_ syncKey: String, run: @escaping @Sendable (Bool) async throws -> Void) {
        self.syncKey = syncKey
        self.run = run
    }

    public func sync(force: Bool) async throws {
        try await run(force)
    }
}
