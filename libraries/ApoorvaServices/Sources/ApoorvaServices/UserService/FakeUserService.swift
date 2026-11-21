//
//  FakeUserService.swift
//  ApoorvaServices
//
//  In-memory UserServiceProtocol used only by UI tests (`-UITesting -UITestingSeed`). Emits nothing until
//  `publish(_:)` is called, so the seeder can fill the local DB while the session still has no org
//  (repositories then never touch Firestore).
//

import Foundation
import ApoorvaModels

@MainActor
public final class FakeUserService: UserServiceProtocol {
    public let userSessionStream: AsyncStream<AppUser?>
    private let continuation: AsyncStream<AppUser?>.Continuation

    public private(set) var currentUser: AppUser?

    public init() {
        let (stream, continuation) = AsyncStream.makeStream(of: AppUser?.self, bufferingPolicy: .bufferingOldest(1))
        self.userSessionStream = stream
        self.continuation = continuation
    }

    /// Sets `currentUser` without emitting on the session stream. Repositories read it via `getCurrentUser()` and throw when it is nil,
    /// so the seeder passes an org-less user here (nothing is written to Firestore without an org).
    public func prepare(_ user: AppUser?) {
        currentUser = user
    }

    /// Signs the fake user in; the session stream then resolves to Home.
    public func publish(_ user: AppUser?) {
        currentUser = user
        continuation.yield(user)
    }

    public func updateSelectedOrganization(for user: AppUser, organization: OrganizationSnapshot) async throws {}

    public func listUsers(orgId: String) async throws -> [AppUser] {
        currentUser.map { [$0] } ?? []
    }

    public func updateRole(userId: String, role: AppUserRole) async throws {}
}
