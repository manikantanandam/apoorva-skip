//
//  UsersMemberRepository.swift
//  ApoorvaRepository
//

import Foundation
import ApoorvaModels

public enum UsersMemberRepositoryError: Error {
    /// Members are derived from `users` docs; change them through the user service instead.
    case readOnly
}

/// The org's members, read from the legacy `users` collection (every user whose `assignedOrgIds` contains the
/// org) instead of a separate `members` collection. Per-org role, store access and salary come from the optional
/// `users/{uid}.orgMembership.{orgId}` entry; legacy users without one keep the role derived from `users.role`.
public final actor UsersMemberRepository: OrgCollectionRepositoryProtocol {
    public typealias Document = Member

    private let userRepository: UserRepositoryProtocol
    private let context: OrgContextProviding

    public nonisolated var syncKey: String { "org.members" }

    public init(userRepository: UserRepositoryProtocol, context: OrgContextProviding) {
        self.userRepository = userRepository
        self.context = context
    }

    public func all() async throws -> [Member] {
        guard let orgId = try await context.currentOrgId() else { return [] }
        return try await userRepository.listUsers(orgId: orgId).map { $0.member(in: orgId) }
    }

    public func get(id: String) async throws -> Member? {
        try await all().first { $0.id == id }
    }

    public func save(_ document: Member) async throws { throw UsersMemberRepositoryError.readOnly }
    public func saveAll(_ documents: [Member]) async throws { throw UsersMemberRepositoryError.readOnly }
    public func delete(id: String) async throws { throw UsersMemberRepositoryError.readOnly }

    public func changes() async -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }

    /// Nothing to pull: `users` is read live.
    public func sync(force: Bool) async throws {}
}
