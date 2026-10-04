//
//  File.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation
import ApoorvaViewModel

// A mock view model purely for SwiftUI Previews
class MockLoginViewModel: LoginViewModelProtocol {
    @Published var username = "testuser"
    @Published var password = "password123"
    
    var isLoginEnabled: Bool { true }
    
    func loginPressed() {
        print("Mock login triggered!")
    }
}
