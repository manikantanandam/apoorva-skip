import Foundation
import FirebaseFirestore
import ApoorvaModels
import FirebaseAuth

@MainActor
public protocol UserServiceProtocol {
    func fetchUserProfile() async throws -> AppUser
}

@MainActor
public class UserService: UserServiceProtocol {
    // 1. The Singleton Instance
    public static let shared = UserService()
    
    private let db = Firestore.firestore()
    
    // Make init private so no one else can create a random instance
    private init() {}
    
    // Custom error for when we try to fetch data but aren't logged in, or data is missing
    enum AuthError: Error, LocalizedError {
        case noUserLoggedIn
        case userDocumentNotFound
        
        var errorDescription: String? {
            switch self {
            case .noUserLoggedIn:
                return "No user is currently logged in."
            case .userDocumentNotFound:
                return "User profile data was not found in the database."
            }
        }
    }
    
    // 2. Fetch directly using Auth.auth() and throw errors instead of returning nil
    public func fetchUserProfile() async throws -> AppUser {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw AuthError.noUserLoggedIn
        }
        
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            
            guard doc.exists else {
                print("❌ User document does not exist in Firestore for UID: \(uid)")
                throw AuthError.userDocumentNotFound
            }
            
            // This is the line that is throwing the error
            return try doc.data(as: AppUser.self)
            
        } catch let DecodingError.dataCorrupted(context) {
            print("❌ Data corrupted: \(context.debugDescription)")
            throw DecodingError.dataCorrupted(context)
        } catch let DecodingError.keyNotFound(key, context) {
            print("❌ Key '\(key.stringValue)' not found: \(context.debugDescription)")
            print("codingPath:", context.codingPath)
            throw DecodingError.keyNotFound(key, context)
        } catch let DecodingError.valueNotFound(value, context) {
            print("❌ Value '\(value)' not found: \(context.debugDescription)")
            print("codingPath:", context.codingPath)
            throw DecodingError.valueNotFound(value, context)
        } catch let DecodingError.typeMismatch(type, context)  {
            print("❌ Type '\(type)' mismatch: \(context.debugDescription)")
            print("codingPath:", context.codingPath)
            throw DecodingError.typeMismatch(type, context)
        } catch {
            print("❌ Unknown error: \(error)")
            throw error
        }
    }
}
