//
//  LoginViewModel.swift
//  ApoorvaViewModel
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation

@Observable
class LoginViewModel: LoginViewModelProtocol {
    
    var username = ""
    var password = ""
    
    // Computed property to keep business logic out of the View
    var isLoginEnabled: Bool {
        !username.isEmpty && !password.isEmpty
    }
    
    func loginPressed() {
        // Handle actual authentication logic here
        print("Logging in with \(username)...")
    }
}
