//
//  SwiftUIView.swift
//  ApoorvaApp
//
//  Created by Manikanta Nandam on 03/10/26.
//

import SwiftUI
import ApoorvaViewModel

public struct LoginView<ViewModel: LoginViewModelProtocol>: View {
    // 1. Inject the ViewModel
    @StateObject private var viewModel: ViewModel
    
    // 2. Focus Lifecycle State remains in the View
    enum Field: Hashable {
        case username
        case password
    }
    @FocusState private var focusedField: Field?
    
    // Custom initializer for dependency injection
    public init(viewModel: @autoclosure @escaping () -> ViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Account Credentials")) {
                    TextField("Username or Email", text: $viewModel.username)
                        .focused($focusedField, equals: .username)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)

                    SecureField("Password", text: $viewModel.password)
                        .focused($focusedField, equals: .password)
                        .textContentType(.password)
                        .submitLabel(.go)
                }
                
                Button(action: viewModel.loginPressed) {
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
                    if viewModel.isLoginEnabled {
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
    LoginView(viewModel: MockLoginViewModel())
    
    // In your actual App entry point, you would inject the real one:
    // LoginView(viewModel: LoginViewModel())
}
