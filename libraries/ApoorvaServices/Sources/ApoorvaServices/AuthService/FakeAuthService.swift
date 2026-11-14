//
//  FakeAuthService.swift
//  ApoorvaServices
//
//  In-memory AuthServicing used only by UI tests (launched with `-UITesting`).
//

import Foundation
import ApoorvaModels

public final class FakeAuthService: AuthServicing, @unchecked Sendable {
    public static let validEmail = "uitest@apoorva.app"
    public static let validPassword = "UITest@123"

    private let lock = NSLock()
    private var account: AuthAccount?
    private var continuations: [UUID: AsyncStream<AuthAccount?>.Continuation] = [:]

    public init() {}

    public var currentAccount: AuthAccount? {
        lock.withLock { account }
    }

    public var accountStream: AsyncStream<AuthAccount?> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock {
                continuations[id] = continuation
                continuation.yield(account)
            }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.continuations.removeValue(forKey: id) }
            }
        }
    }

    public var currentUserStream: AsyncStream<AppUser?> {
        let accounts = accountStream
        return AsyncStream { continuation in
            let task = Task {
                for await account in accounts {
                    continuation.yield(account.map {
                        AppUser(id: $0.uid, name: "UI Test", email: $0.email ?? "", role: .standard, status: "",
                                assignedOrgs: [], createdAt: Date(), updatedAt: Date())
                    })
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func login(email: String, password: String) async throws {
        guard email == Self.validEmail, password == Self.validPassword else {
            throw AuthServiceError.message("Email or password is incorrect.")
        }
        publish(AuthAccount(uid: "uitest-uid", email: email, isEmailVerified: true))
    }

    public func logout() throws {
        publish(nil)
    }

    private func publish(_ newAccount: AuthAccount?) {
        lock.withLock {
            account = newAccount
            continuations.values.forEach { $0.yield(newAccount) }
        }
    }
}
