//
//  SwiftUIView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 04/10/26.
//

import SwiftUI

struct PasswordTextField: View {
    
    @Binding private var password: String
    @State var showPassword: Bool = false
    private let placeholder: String
    private let iconColor: Color? = nil
    private let minHeight: CGFloat
    private let padding: CGFloat
    private let backgroundColor: ApoorvaColor
    
    public init(password: Binding<String>,
                placeholder: String = "Password",
                minHeight: CGFloat = 60,
                padding: CGFloat = 16,
                backgroundColor: ApoorvaColor = .textFieldBackground) {
        self._password = password
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.padding = padding
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        textField
            .textContentType(.password)
            .submitLabel(.go)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
            .background(backgroundColor.color)
            .overlay(alignment: .trailing) {
                icon
            }
    }
    
    @ViewBuilder var textField: some View {
        if showPassword {
            CustomTextField(text: $password, placeholder: placeholder)
        } else {
            SecureField(placeholder, text: $password)
                .padding(.horizontal, padding)
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
