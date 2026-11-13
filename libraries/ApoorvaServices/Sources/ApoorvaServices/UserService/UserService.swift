import Foundation
import FirebaseFirestore
import FirebaseAuth
import ApoorvaModels
import ApoorvaLogging

private let logger = AppLogger(category: .auth)

/// The signed-in account plus its profile doc (nil when the doc doesn't exist yet).
public struct SessionSnapshot: Sendable, Equatable {
    public let account: AuthAccount?
    public let profile: AppUser?

    public init(account: AuthAccount?, profile: AppUser?) {
        self.account = account
        self.profile = profile
    }

    public static func == (lhs: SessionSnapshot, rhs: SessionSnapshot) -> Bool {
        lhs.account == rhs.account
            && lhs.profile?.id == rhs.profile?.id
            && lhs.profile?.selectedOrganization?.orgId == rhs.profile?.selectedOrganization?.orgId
            && lhs.profile?.role == rhs.profile?.role
            && encodedProfile(lhs.profile) == encodedProfile(rhs.profile)
    }

    /// Compares every profile field, not just the timestamp: console edits can change fields without bumping it.
    private static func encodedProfile(_ profile: AppUser?) -> Data? {
        profile.flatMap { try? JSONEncoder().encode($0) }
    }
}

@MainActor
public protocol UserServiceProtocol: Sendable {
    // Expose the fully populated user session
    var userSessionStream: AsyncStream<AppUser?> { get }

    /// Account + live profile. Emits on sign-in/out and whenever `users/{uid}` changes.
    var sessionStream: AsyncStream<SessionSnapshot> { get }

    var currentUser: AppUser? { get }

    func updateSelectedOrganization(
        for user: AppUser,
        organization: OrganizationSnapshot
    ) async throws

    func listUsers(orgId: String) async throws -> [AppUser]

    func updateRole(userId: String, role: AppUserRole) async throws

    /// Creates the `users/{uid}` profile doc for a new account (onboarding).
    func createProfile(for account: AuthAccount, name: String, role: AppUserRole, organization: OrganizationSnapshot?) async throws

    func setAssignedOrganizations(userId: String, organizations: [OrganizationSnapshot], selected: OrganizationSnapshot) async throws
}

public extension UserServiceProtocol {
    var sessionStream: AsyncStream<SessionSnapshot> {
        let users = userSessionStream
        return AsyncStream { continuation in
            let task = Task {
                for await user in users {
                    continuation.yield(SessionSnapshot(
                        account: user.map { AuthAccount(uid: $0.id, email: $0.email, isEmailVerified: true) },
                        profile: user
                    ))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    func createProfile(for account: AuthAccount, name: String, role: AppUserRole, organization: OrganizationSnapshot?) async throws {}
    func setAssignedOrganizations(userId: String, organizations: [OrganizationSnapshot], selected: OrganizationSnapshot) async throws {}
}

@MainActor
public class UserService: UserServiceProtocol {
    private let store: FirestoreStoring
    private let authService: AuthServicing
    private var sessionTask: Task<Void, Never>?
    
    // The stream consumed by AppCoordinator
    public let userSessionStream: AsyncStream<AppUser?>
    private let sessionContinuation: AsyncStream<AppUser?>.Continuation
    
    public private(set) var currentUser: AppUser?
    
    // 1. Dependency Injection (Replaces the Singleton)
    public init(authService: AuthServicing, store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.authService = authService
        self.store = store
        
        let (stream, continuation) = AsyncStream.makeStream(
            of: AppUser?.self,
            bufferingPolicy: .bufferingOldest(1)
        )
        self.userSessionStream = stream
        self.sessionContinuation = continuation
        logger.debug("Started listening for auth")
        startListeningToAuth()
    }
    
    private func startListeningToAuth() {
        sessionTask = Task { [weak self] in
            guard let self else { return }
            
            // 2. Listen to the base Firebase state from AuthService
            for await partialUser in self.authService.currentUserStream {
                if let uid = partialUser?.id {
                    do {
                        let fullUser = try await self.fetchUserProfile(uid: uid)
                        self.currentUser = fullUser
                        self.sessionContinuation.yield(fullUser)
                    } catch {
                        logger.error("Failed to fetch full user profile:\(error)")
                        self.currentUser = nil
                        // Route back to login if the Firestore document is missing/corrupted
                        self.sessionContinuation.yield(nil)
                    }
                } else {
                    // Firebase logged out
                    self.currentUser = nil
                    self.sessionContinuation.yield(nil)
                }
            }
        }
    }
    
    deinit {
        sessionTask?.cancel()
    }
    
    enum AuthError: Error, LocalizedError {
        case noUserLoggedIn
        case userDocumentNotFound
        
        var errorDescription: String? {
            switch self {
            case .noUserLoggedIn: return "No user is currently logged in."
            case .userDocumentNotFound: return "User profile data was not found in the database."
            }
        }
    }
    
    // 4. Accept UID directly to avoid calling Auth.auth() redundantly
    public func fetchUserProfile(uid: String) async throws -> AppUser {
        
        do {
            guard let doc = try await store.getDocument(path: "\(String.users)/\(uid)") else {
                logger.warning("User document does not exist in Firestore for UID:\(uid)")
                throw AuthError.userDocumentNotFound
            }

            return try Firestore.Decoder().decode(AppUser.self, from: doc.data)
            
        } catch {
            // Keep your existing detailed catch blocks here
            logger.error("User decode error:\(error)")
            throw error
        }
    }
    
    public func updateSelectedOrganization(
        for user: AppUser,
        organization: OrganizationSnapshot
    ) async throws {
        do {
            let encodedOrg = try Firestore.Encoder().encode(organization)

            try await store.updateData([
                "selectedOrganization": encodedOrg,
                "updatedTimestamp": Date().timeIntervalSince1970
            ], path: "\(String.users)/\(user.id)")
            
        } catch {
            logger.error("User update error:\(error)")
            throw error
        }
    }

    public func listUsers(orgId: String) async throws -> [AppUser] {
        try await store.fetch(
            AppUser.self,
            collection: String.users,
            query: StoreQuery(conditions: [.arrayContains(field: "assignedOrgIds", value: orgId)])
        )
    }

    public var sessionStream: AsyncStream<SessionSnapshot> {
        let accounts = authService.accountStream
        let store = self.store
        return AsyncStream { continuation in
            let task = Task { @MainActor in
                var profileTask: Task<Void, Never>?
                for await account in accounts {
                    profileTask?.cancel()
                    guard let account else {
                        self.currentUser = nil
                        continuation.yield(SessionSnapshot(account: nil, profile: nil))
                        continue
                    }
                    profileTask = Task { @MainActor in
                        for await document in store.listen(path: "\(String.users)/\(account.uid)") {
                            let profile = document.flatMap { try? Firestore.Decoder().decode(AppUser.self, from: Self.withId($0)) }
                            self.currentUser = profile
                            continuation.yield(SessionSnapshot(account: account, profile: profile))
                        }
                    }
                }
                profileTask?.cancel()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func withId(_ document: StoreDocument) -> [String: Any] {
        var data = document.data
        if data["id"] == nil { data["id"] = document.id }
        return data
    }

    public func createProfile(for account: AuthAccount, name: String, role: AppUserRole, organization: OrganizationSnapshot?) async throws {
        var data: [String: Any] = [
            "id": account.uid,
            "name": name,
            "email": account.email ?? "",
            "role": role.rawValue,
            "status": "active",
            "assignedOrgs": [],
            "assignedOrgIds": [],
            "createdAt": Date(),
            "updatedAt": Date(),
            "updatedTimestamp": Date().timeIntervalSince1970,
            "url": "",
            "isDeleted": false
        ]
        if let organization {
            let encoded = try Firestore.Encoder().encode(organization)
            data["assignedOrgs"] = [encoded]
            data["assignedOrgIds"] = [organization.orgId]
            data["selectedOrganization"] = encoded
        }
        try store.setData(data, path: "\(String.users)/\(account.uid)", merge: true)
    }

    public func setAssignedOrganizations(userId: String, organizations: [OrganizationSnapshot], selected: OrganizationSnapshot) async throws {
        let encoded = try organizations.map { try Firestore.Encoder().encode($0) }
        try store.setData([
            "assignedOrgs": encoded,
            "assignedOrgIds": organizations.map(\.orgId),
            "selectedOrganization": try Firestore.Encoder().encode(selected),
            "updatedTimestamp": Date().timeIntervalSince1970
        ], path: "\(String.users)/\(userId)", merge: true)
    }

    public func updateRole(userId: String, role: AppUserRole) async throws {
        do {
            try await store.updateData([
                "role": role.rawValue,
                "updatedTimestamp": Date().timeIntervalSince1970
            ], path: "\(String.users)/\(userId)")
        } catch {
            logger.error("User role update error:\(error)")
            throw error
        }
    }
}
