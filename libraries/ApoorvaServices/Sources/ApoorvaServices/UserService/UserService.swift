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
}

@MainActor
public class UserService: UserServiceProtocol {
    private let db = Firestore.firestore()
    private let authService: AuthServicing
    private var sessionTask: Task<Void, Never>?
    
    // The stream consumed by MainViewModel
    public let userSessionStream: AsyncStream<AppUser?>
    private let sessionContinuation: AsyncStream<AppUser?>.Continuation
    
    public private(set) var currentUser: AppUser?
    
    // 1. Dependency Injection (Replaces the Singleton)
    public init(authService: AuthServicing) {
        self.authService = authService
        
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
            let doc = try await db.collection("users").document(uid).getDocument()
            
            guard doc.exists else {
                print("❌ User document does not exist in Firestore for UID: \(uid)")
                throw AuthError.userDocumentNotFound
            }
            
            return try doc.data(as: AppUser.self)
            
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
            let userRef = try db.collection(.users).document(user.id)
            
            let encodedOrg = try Firestore.Encoder().encode(organization)
            
            try await userRef.updateData([
                "selectedOrganization": encodedOrg,
                "updatedTimestamp": Date().timeIntervalSince1970
            ])
            
        } catch {
            print("❌ Update error: \(error)")
            throw error
        }
    }
}
