//
//  LoginViewModel.swift
//  ApoorvaModules
//

import Foundation
import ApoorvaServices
import ApoorvaUtilities
import ApoorvaEnvironment

/// Email sign-in (design 07). On success the session stream moves the app forward on its own.
@MainActor
@Observable
public class LoginViewModel {
    public var username: String
    var password: String
    var isLoggingIn = false
    var errorMessage: String?
    /// Called when the email belongs to an account with another sign-in method (design 12).
    public var onNeedsLinking: ((String) -> Void)?

    private var authService: AuthServicing

    public init(authService: AuthServicing, environment: AppEnvironment) {
        self.authService = authService
        #if DEBUG
        // Test accounts are prefilled only in debug builds.
        switch environment {
        case .debug: self.username = "lavanya@gmail.com"
        case .production: self.username = ""
        }
        self.password = environment == .debug ? "Apoorva@123" : ""
        #else
        self.username = ""
        self.password = ""
        #endif
    }

    var isLoginEnabled: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    func loginPressed() {
        guard isLoginEnabled else { return }
        errorMessage = nil
        isLoggingIn = true
        Task(name: "login task") {
            defer { isLoggingIn = false }
            do {
                try await authService.login(email: username.trimmingCharacters(in: .whitespaces), password: password)
            } catch AuthServiceError.accountExistsWithDifferentCredential(let email) {
                onNeedsLinking?(email)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
