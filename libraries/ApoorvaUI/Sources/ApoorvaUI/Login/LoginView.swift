//
//  SwiftUIView.swift
//  ApoorvaApp
//
//  Created by Manikanta Nandam on 03/10/26.
//

import SwiftUI

public struct LoginView: View {
    // 1. Inject the ViewModel
    @Bindable private var viewModel: LoginViewModel
    
    // 2. Focus Lifecycle State remains in the View
    enum Field: Hashable {
        case username
        case password
    }
    @FocusState private var focusedField: Field?
    
    // Custom initializer for dependency injection
    public init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            VStack {
                EmailTextField(text: $viewModel.username)
                    .focused($focusedField, equals: .username)
                    

                PasswordTextField(password: $viewModel.password)
                    .focused($focusedField, equals: .password)
                
                CustomButton(text: "Login",
                             needLoader: true,
                             backgroundColor: .orange) {
                    viewModel.loginPressed()
                }
            }
            .padding(16)
            .onAppear {
                focusedField = .username
            }
        }
    }
}

#Preview {
    // Injecting the Mock
//    LoginView(viewModel: LoginViewModel())
    
    // In your actual App entry point, you would inject the real one:
    // LoginView(viewModel: LoginViewModel())
}
