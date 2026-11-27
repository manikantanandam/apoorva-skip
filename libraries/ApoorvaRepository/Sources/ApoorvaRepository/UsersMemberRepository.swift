//
//  UsersMemberRepository.swift
//  ApoorvaRepository
//

import Foundation
import ApoorvaModels
import ApoorvaServices
import ManiLogger

private let logger = AppLogger(category: .sync)

/// Same FNV-1a recipe as `CrashReportingServicing.stableHash` (not callable here: it's a static member
/// on a protocol extension, and `crashReportingService` is only known as `any CrashReportingServicing`).
private func stableHash(_ value: String) -> String {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in value.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return String(hash, radix: 16)
}

public enum UsersMemberRepositoryError: Error {
    /// Members are derived from `users` docs; change them through the user service instead.
    case readOnly
    /// `listUsers(orgId:)` came back empty for a resolved org. Every org has at least an owner, so this means
    /// the org's `users` docs predate the `assignedOrgIds` field `UserService.listUsers` filters on (introduced
    /// in #103, 2026-11-22) and were never backfilled — see `ApoorvaServices/Context.md`'s "Firestore query seam".
    case membersQueryReturnedEmptyForResolvedOrg
}

/// The org's members, read from the legacy `users` collection (every user whose `assignedOrgIds` contains the
/// org) instead of a separate `members` collection. Per-org role, store access and salary come from the optional
/// `users/{uid}.orgMembership.{orgId}` entry; legacy users without one keep the role derived from `users.role`.
public final actor UsersMemberRepository: OrgCollectionRepositoryProtocol {
    public typealias Document = Member

    private let userRepository: UserRepositoryProtocol
    private let context: OrgContextProviding
    private let crashReportingService: CrashReportingServicing
    private let analyticsService: AnalyticsServicing
    /// Reported at most once per app run so a broken org doesn't spam Crashlytics/Analytics on every screen that
    /// reads members (PIN switch, Bills, People, POS, Insights, Team all call `all()` independently).
    private var hasReportedEmptyMembership = false

    public nonisolated var syncKey: String { "org.members" }

    public init(userRepository: UserRepositoryProtocol, context: OrgContextProviding,
                crashReportingService: CrashReportingServicing, analyticsService: AnalyticsServicing) {
        self.userRepository = userRepository
        self.context = context
        self.crashReportingService = crashReportingService
        self.analyticsService = analyticsService
    }

    public func all() async throws -> [Member] {
        guard let orgId = try await context.currentOrgId() else { return [] }
        let users = try await userRepository.listUsers(orgId: orgId)
        if users.isEmpty, !hasReportedEmptyMembership {
            hasReportedEmptyMembership = true
            logger.error("Org \(orgId) resolved but listUsers(orgId:) returned 0 users — every org has an owner, so its users docs are likely missing assignedOrgIds")
            crashReportingService.recordNonFatal(UsersMemberRepositoryError.membersQueryReturnedEmptyForResolvedOrg,
                                                   context: "UsersMemberRepository.all")
            analyticsService.log(.orgMembersQueryEmpty(orgIdHash: stableHash(orgId)))
        }
        return users.map { $0.member(in: orgId) }
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
