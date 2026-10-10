//
//  SwiftUIView.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 04/10/26.
//

import SwiftUI

struct PasswordTextField: View {
    
    @Binding private var password: String
    @State var showPassword: Bool = false
    private let placeholder: String
    private let iconColor: Color? = nil
    
    public init(password: Binding<String>,
                placeholder: String = "Password") {
        self._password = password
        self.placeholder = placeholder
    }
    
    var body: some View {
        textField
            .textContentType(.password)
            .submitLabel(.go)
            .overlay(alignment: .trailing) {
                icon
            }
    }
    
    @ViewBuilder var textField: some View {
        if showPassword {
            CustomTextField(text: $password, placeholder: placeholder)
        } else {
            SecureField(placeholder, text: $password)
        }
    }
    
    @ViewBuilder var icon: some View {
        if let iconColor {
            IconView(icon: .person, iconSize: 24, color: iconColor)
        } else {
            EmptyView()
        }
    }
    
}

#Preview {
    PasswordTextField(password: .constant("Password@123"))
}
