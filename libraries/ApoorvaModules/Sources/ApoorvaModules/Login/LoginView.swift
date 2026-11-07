//
//  SwiftUIView.swift
//  ApoorvaApp
//
//  Created by Manikanta Nandam on 03/10/26.
//

import SwiftUI
import ManiSwiftUIComponents

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
            VStack(spacing: ManiSpacing.md) {
                ManiInputField(
                    label: "Email",
                    text: $viewModel.username,
                    placeholder: "you@example.com",
                    keyboard: .email
                )
                .focused($focusedField, equals: .username)

                ManiInputField(
                    label: "Password",
                    text: $viewModel.password,
                    placeholder: "Password",
                    isSecure: true
                )
                .focused($focusedField, equals: .password)

                if let errorMessage = viewModel.errorMessage {
                    ManiNote(errorMessage, kind: .error)
                }

                ManiButton(
                    "Login",
                    kind: .primary,
                    isLoading: viewModel.isLoggingIn,
                    isEnabled: viewModel.isLoginEnabled
                ) {
                    viewModel.loginPressed()
                }
            }
            .padding(ManiSpacing.lg)
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
