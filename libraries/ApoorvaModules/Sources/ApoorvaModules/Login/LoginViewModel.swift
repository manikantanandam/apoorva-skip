//
//  LoginViewModel.swift
//  ApoorvaModules
//

import Foundation
import SkipFuse
import Observation
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
    private let analyticsService: AnalyticsServicing

    public init(authService: AuthServicing, environment: AppEnvironment, analyticsService: AnalyticsServicing = NoOpAnalyticsService()) {
        self.authService = authService
        self.analyticsService = analyticsService
        #if DEBUG
        // The first test account is prefilled only in debug builds against the debug environment.
        let testUser = environment == .debug ? DebugTestUsers.all.first : nil
        self.username = testUser?.email ?? ""
        self.password = testUser?.password ?? ""
        #else
        self.username = ""
        self.password = ""
        #endif
    }

    #if DEBUG
    func selectDebugUser(_ user: DebugTestUser) {
        username = user.email
        password = user.password
        errorMessage = nil
    }
    #endif

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
                analyticsService.log(.signInMethod("email"))
            } catch AuthServiceError.accountExistsWithDifferentCredential(let email) {
                onNeedsLinking?(email)
            } catch {
                errorMessage = UserFacingError.message(for: error)
            }
        }
    }
}
