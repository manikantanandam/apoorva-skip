import Foundation
import FirebaseFirestore
import FirebaseAuth
import ApoorvaModels

@MainActor
public protocol UserServiceProtocol: Sendable {
    // Expose the fully populated user session
    var userSessionStream: AsyncStream<AppUser?> { get }
}

@MainActor
public class UserService: UserServiceProtocol {
    private let db = Firestore.firestore()
    private let authService: AuthServicing
    private var sessionTask: Task<Void, Never>?
    
    // The stream consumed by MainViewModel
    public let userSessionStream: AsyncStream<AppUser?>
    private let sessionContinuation: AsyncStream<AppUser?>.Continuation
    
    // 1. Dependency Injection (Replaces the Singleton)
    public init(authService: AuthServicing) {
        self.authService = authService
        
        let (stream, continuation) = AsyncStream.makeStream(of: AppUser?.self)
        self.userSessionStream = stream
        self.sessionContinuation = continuation
        
        startListeningToAuth()
    }
    
    private func startListeningToAuth() {
        sessionTask = Task { [weak self] in
            guard let self else { return }
            
            // 2. Listen to the base Firebase state from AuthService
            for await partialUser in self.authService.currentUserStream {
                if let uid = partialUser?.id {
                    do {
                        // 3. Fetch full details and publish to the app
                        print("Fetching the User details using user service")
                        let fullUser = try await self.fetchUserProfile(uid: uid)
                        print("Got the full user")
                        self.sessionContinuation.yield(fullUser)
                    } catch {
                        print("❌ Failed to fetch full user profile: \(error)")
                        // Route back to login if the Firestore document is missing/corrupted
                        self.sessionContinuation.yield(nil)
                    }
                } else {
                    // Firebase logged out
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
}
