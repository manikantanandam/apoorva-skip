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
            Form {
                Section(header: Text("Account Credentials")) {
                    EmailTextField(text: $viewModel.username)
                        .focused($focusedField, equals: .username)

                    PasswordTextField(password: $viewModel.password)
                        .focused($focusedField, equals: .password)
                }
                
                Button {
                    viewModel.loginPressed()
                } label: {
                    Text("Log In")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(!viewModel.isLoginEnabled) // Logic moved to ViewModel
            }
            .navigationTitle("Welcome")
            .onSubmit {
                switch focusedField {
                case .username:
                    focusedField = .password
                case .password:
                    Task {
                        viewModel.loginPressed()
                    }

                case nil:
                    break
                }
            }
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
