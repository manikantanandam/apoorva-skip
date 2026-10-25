//
//  LoginViewModel.swift
//  ApoorvaViewModel
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation
import ApoorvaServices

@MainActor
@Observable
public class LoginViewModel {
    
    var username = "manikantanandam1996@gmail.com"
    var password = "Apoorva@123"
    
    private var authService: AuthServicing
    
    public init(authService: AuthServicing) {
        self.authService = authService
    }
    
    // Computed property to keep business logic out of the View
    var isLoginEnabled: Bool {
        !username.isEmpty && !password.isEmpty
    }
    
    func loginPressed() {
        // Handle actual authentication logic here
        guard isLoginEnabled else { return }
        Task(name: "login task") {
            do {
                try await authService.login(email: username, password: password)
            } catch {
                print("Error \(error)")
            }
            
        }
    }
}
