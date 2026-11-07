import Foundation
import FirebaseFirestore
import FirebaseAuth
import ApoorvaModels

@MainActor
public protocol UserServiceProtocol: Sendable {
    // Expose the fully populated user session
    var userSessionStream: AsyncStream<AppUser?> { get }
    
    var currentUser: AppUser? { get }

    func updateSelectedOrganization(
        for user: AppUser,
        organization: OrganizationSnapshot
    ) async throws

    func listUsers(orgId: String) async throws -> [AppUser]

    func updateRole(userId: String, role: AppUserRole) async throws
}

@MainActor
public class UserService: UserServiceProtocol {
    private let store: FirestoreStoring
    private let authService: AuthServicing
    private var sessionTask: Task<Void, Never>?
    
    // The stream consumed by MainViewModel
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
        print("Started listening for auth")
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
                        print("❌ Failed to fetch full user profile: \(error)")
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
                print("❌ User document does not exist in Firestore for UID: \(uid)")
                throw AuthError.userDocumentNotFound
            }

            return try Firestore.Decoder().decode(AppUser.self, from: doc.data)
            
        } catch {
            // Keep your existing detailed catch blocks here
            print("❌ Decode error: \(error)")
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
            print("❌ Update error: \(error)")
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

    public func updateRole(userId: String, role: AppUserRole) async throws {
        do {
            try await store.updateData([
                "role": role.rawValue,
                "updatedTimestamp": Date().timeIntervalSince1970
            ], path: "\(String.users)/\(userId)")
        } catch {
            print("❌ Update role error: \(error)")
            throw error
        }
    }
}
