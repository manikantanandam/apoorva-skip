//
//  LoginViewModel.swift
//  ApoorvaViewModel
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation
import ApoorvaServices
import ApoorvaUtilities

@MainActor
@Observable
public class LoginViewModel {

    var username: String
    var password = "Apoorva@123"
    var isLoggingIn = false
    var errorMessage: String?

    private var authService: AuthServicing

    public init(authService: AuthServicing, environment: AppEnvironment) {
        self.authService = authService
        switch environment {
        case .debug: self.username = "lavanya@gmail.com"
        case .production: self.username = "manikantanandam1996@gmail.com"
        }
    }

    // Computed property to keep business logic out of the View
    var isLoginEnabled: Bool {
        !username.isEmpty && !password.isEmpty
    }

    func loginPressed() {
        // Handle actual authentication logic here
        guard isLoginEnabled else { return }
        errorMessage = nil
        isLoggingIn = true
        Task(name: "login task") {
            defer { isLoggingIn = false }
            do {
                try await authService.login(email: username, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
