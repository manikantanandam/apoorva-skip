//
//  AuthService.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels
import FirebaseAuth

public enum AuthServiceError: Error, LocalizedError, Equatable {
    case notSignedIn
    case unsupported
    /// The email belongs to an account created with another sign-in method.
    case accountExistsWithDifferentCredential(email: String)
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .notSignedIn: "You're not signed in."
        case .unsupported: "This sign-in method isn't available yet."
        case .accountExistsWithDifferentCredential: "An account already exists with this email."
        case .message(let text): text
        }
    }
}

public protocol AuthServicing: Sendable {
    var currentUserStream: AsyncStream<AppUser?> { get }
    /// Emits the signed-in account (with email-verified state) or nil, on every auth change.
    var accountStream: AsyncStream<AuthAccount?> { get }
    var currentAccount: AuthAccount? { get }
    func login(email: String, password: String) async throws
    func logout() throws
    func register(name: String, email: String, password: String) async throws
    func sendEmailVerification() async throws
    /// Re-reads the account from the server (e.g. after the user taps the verify link).
    @discardableResult func reloadAccount() async throws -> AuthAccount?
    func sendPasswordReset(email: String) async throws
    /// Adds an email/password sign-in to the current account.
    func linkEmail(email: String, password: String) async throws
    func updatePassword(_ password: String) async throws
    func linkedProviders() -> [String]
}

public extension AuthServicing {
    var accountStream: AsyncStream<AuthAccount?> {
        let users = currentUserStream
        return AsyncStream { continuation in
            let task = Task {
                for await user in users {
                    continuation.yield(user.map { AuthAccount(uid: $0.id, email: $0.email, isEmailVerified: true) })
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    var currentAccount: AuthAccount? { nil }
    func register(name: String, email: String, password: String) async throws { throw AuthServiceError.unsupported }
    func sendEmailVerification() async throws { throw AuthServiceError.unsupported }
    func reloadAccount() async throws -> AuthAccount? { nil }
    func sendPasswordReset(email: String) async throws { throw AuthServiceError.unsupported }
    func linkEmail(email: String, password: String) async throws { throw AuthServiceError.unsupported }
    func updatePassword(_ password: String) async throws { throw AuthServiceError.unsupported }
    func linkedProviders() -> [String] { ["password"] }
}

/// What the service needs to know about the signed-in Firebase user.
struct AuthUserInfo: Sendable, Equatable {
    let uid: String
    let email: String?
    let displayName: String?
    let isEmailVerified: Bool
    let providerIDs: [String]
}

/// Thin seam over `FirebaseAuth` so `AuthService`'s logic can be tested without a Firebase backend.
protocol AuthBackend: Sendable {
    var currentUser: AuthUserInfo? { get }
    func signIn(email: String, password: String) async throws
    func signOut() throws
    /// Creates the account, sets its display name and sends the verification email.
    func createUser(name: String, email: String, password: String) async throws
    func sendEmailVerification() async throws
    func reloadUser() async throws
    func sendPasswordReset(email: String) async throws
    func link(email: String, password: String) async throws
    func updatePassword(_ password: String) async throws
    /// Calls `handler` now and on every auth change; the returned closure removes the listener.
    func observe(_ handler: @escaping @Sendable (AuthUserInfo?) -> Void) -> @Sendable () -> Void
}

public final class AuthService: AuthServicing {

    private let backend: AuthBackend

    public convenience init() {
        self.init(backend: FirebaseAuthBackend())
    }

    init(backend: AuthBackend) {
        self.backend = backend
    }

    public func login(email: String, password: String) async throws {
        do {
            try await backend.signIn(email: email, password: password)
        } catch {
            throw Self.mapped(error, email: email)
        }
    }

    public func logout() throws {
        try backend.signOut()
    }

    public func register(name: String, email: String, password: String) async throws {
        do {
            try await backend.createUser(name: name, email: email, password: password)
        } catch {
            throw Self.mapped(error, email: email)
        }
    }

    public func sendEmailVerification() async throws {
        guard backend.currentUser != nil else { throw AuthServiceError.notSignedIn }
        try await backend.sendEmailVerification()
    }

    @discardableResult
    public func reloadAccount() async throws -> AuthAccount? {
        guard backend.currentUser != nil else { return nil }
        try await backend.reloadUser()
        return Self.account(from: backend.currentUser)
    }

    public func sendPasswordReset(email: String) async throws {
        do {
            try await backend.sendPasswordReset(email: email)
        } catch {
            throw Self.mapped(error, email: email)
        }
    }

    public func linkEmail(email: String, password: String) async throws {
        guard backend.currentUser != nil else { throw AuthServiceError.notSignedIn }
        do {
            try await backend.link(email: email, password: password)
        } catch {
            throw Self.mapped(error, email: email)
        }
    }

    public func updatePassword(_ password: String) async throws {
        guard backend.currentUser != nil else { throw AuthServiceError.notSignedIn }
        try await backend.updatePassword(password)
    }

    public func linkedProviders() -> [String] {
        backend.currentUser?.providerIDs ?? []
    }

    public var currentAccount: AuthAccount? {
        Self.account(from: backend.currentUser)
    }

    public var accountStream: AsyncStream<AuthAccount?> {
        let backend = self.backend
        return AsyncStream { continuation in
            let remove = backend.observe { user in
                continuation.yield(Self.account(from: user))
            }
            continuation.onTermination = { _ in remove() }
        }
    }

    public var currentUserStream: AsyncStream<AppUser?> {
        let backend = self.backend
        return AsyncStream { continuation in
            let remove = backend.observe { user in
                guard let user else {
                    continuation.yield(nil)
                    return
                }
                continuation.yield(AppUser(id: user.uid, name: user.displayName ?? "", email: user.email ?? "",
                                           role: .standard, status: "", assignedOrgs: [], createdAt: Date(), updatedAt: Date()))
            }
            continuation.onTermination = { _ in remove() }
        }
    }

    static func account(from user: AuthUserInfo?) -> AuthAccount? {
        guard let user else { return nil }
        // Accounts with no email sign-in (phone/Google) don't need email verification.
        let hasPassword = user.providerIDs.contains(EmailAuthProviderID)
        return AuthAccount(uid: user.uid, email: user.email, isEmailVerified: user.isEmailVerified || !hasPassword)
    }

    static func mapped(_ error: Error, email: String) -> Error {
        let nsError = error as NSError
        let code = nsError.domain == AuthErrorDomain ? AuthErrorCode(rawValue: nsError.code) : nil
        switch code {
        case .accountExistsWithDifferentCredential, .credentialAlreadyInUse:
            return AuthServiceError.accountExistsWithDifferentCredential(email: email)
        case .emailAlreadyInUse:
            return AuthServiceError.message("An account with this email already exists. Sign in instead.")
        case .wrongPassword, .invalidCredential:
            return AuthServiceError.message("Email or password is incorrect.")
        case .userNotFound:
            return AuthServiceError.message("No account found for this email.")
        case .weakPassword:
            return AuthServiceError.message("Use at least 6 characters for your password.")
        case .invalidEmail:
            return AuthServiceError.message("Enter a valid email address.")
        case .networkError:
            return AuthServiceError.message("No internet connection. Try again when you're online.")
        case .tooManyRequests:
            return AuthServiceError.message("Too many attempts. Wait a minute and try again.")
        default:
            return error
        }
    }
}

// MARK: - Firebase adapter (SDK calls only, no logic)

private struct SendableAuthHandle: @unchecked Sendable {
    let value: AuthStateDidChangeListenerHandle
}

struct FirebaseAuthBackend: AuthBackend {

    var currentUser: AuthUserInfo? { Self.info(Auth.auth().currentUser) }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func createUser(name: String, email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let change = result.user.createProfileChangeRequest()
        change.displayName = name
        try await change.commitChanges()
        try await result.user.sendEmailVerification()
    }

    func sendEmailVerification() async throws {
        try await Auth.auth().currentUser?.sendEmailVerification()
    }

    func reloadUser() async throws {
        try await Auth.auth().currentUser?.reload()
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func link(email: String, password: String) async throws {
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await Auth.auth().currentUser?.link(with: credential)
    }

    func updatePassword(_ password: String) async throws {
        try await Auth.auth().currentUser?.updatePassword(to: password)
    }

    func observe(_ handler: @escaping @Sendable (AuthUserInfo?) -> Void) -> @Sendable () -> Void {
        let handle = SendableAuthHandle(value: Auth.auth().addStateDidChangeListener { _, user in
            handler(Self.info(user))
        })
        return { Auth.auth().removeStateDidChangeListener(handle.value) }
    }

    private static func info(_ user: User?) -> AuthUserInfo? {
        user.map {
            AuthUserInfo(uid: $0.uid, email: $0.email, displayName: $0.displayName,
                         isEmailVerified: $0.isEmailVerified, providerIDs: $0.providerData.map(\.providerID))
        }
    }
}
