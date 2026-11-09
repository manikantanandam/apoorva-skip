//
//  AuthService.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels
import FirebaseAuth

struct SendableAuthHandle: @unchecked Sendable {
    let value: AuthStateDidChangeListenerHandle
}

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

public final class AuthService: AuthServicing {

    public init() {}

    public func login(email: String, password: String) async throws {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw Self.mapped(error, email: email)
        }
    }

    public func logout() throws {
        try Auth.auth().signOut()
    }

    public func register(name: String, email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let change = result.user.createProfileChangeRequest()
            change.displayName = name
            try await change.commitChanges()
            try await result.user.sendEmailVerification()
        } catch {
            throw Self.mapped(error, email: email)
        }
    }

    public func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.notSignedIn }
        try await user.sendEmailVerification()
    }

    @discardableResult
    public func reloadAccount() async throws -> AuthAccount? {
        guard let user = Auth.auth().currentUser else { return nil }
        try await user.reload()
        return Self.account(from: Auth.auth().currentUser)
    }

    public func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw Self.mapped(error, email: email)
        }
    }

    public func linkEmail(email: String, password: String) async throws {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.notSignedIn }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        do {
            try await user.link(with: credential)
        } catch {
            throw Self.mapped(error, email: email)
        }
    }

    public func updatePassword(_ password: String) async throws {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.notSignedIn }
        try await user.updatePassword(to: password)
    }

    public func linkedProviders() -> [String] {
        Auth.auth().currentUser?.providerData.map(\.providerID) ?? []
    }

    public var currentAccount: AuthAccount? {
        Self.account(from: Auth.auth().currentUser)
    }

    public var accountStream: AsyncStream<AuthAccount?> {
        AsyncStream { continuation in
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                continuation.yield(Self.account(from: user))
            }
            let sendableHandle = SendableAuthHandle(value: handle)
            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(sendableHandle.value)
            }
        }
    }

    public var currentUserStream: AsyncStream<AppUser?> {
        AsyncStream { continuation in
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                guard let user else {
                    continuation.yield(nil)
                    return
                }
                continuation.yield(AppUser(id: user.uid, name: user.displayName ?? "", email: user.email ?? "",
                                           role: .standard, status: "", assignedOrgs: [], createdAt: Date(), updatedAt: Date()))
            }
            let sendableHandle = SendableAuthHandle(value: handle)
            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(sendableHandle.value)
            }
        }
    }

    private static func account(from user: User?) -> AuthAccount? {
        guard let user else { return nil }
        // Accounts with no email sign-in (phone/Google) don't need email verification.
        let hasPassword = user.providerData.contains { $0.providerID == EmailAuthProviderID }
        return AuthAccount(uid: user.uid, email: user.email, isEmailVerified: user.isEmailVerified || !hasPassword)
    }

    private static func mapped(_ error: Error, email: String) -> Error {
        let code = AuthErrorCode(_bridgedNSError: error as NSError)?.code
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
