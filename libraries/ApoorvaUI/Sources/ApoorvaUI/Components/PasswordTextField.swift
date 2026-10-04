//
//  SwiftUIView.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 04/10/26.
//

import SwiftUI

struct PasswordTextField: View {
    
    @Binding var password: String
    
    var body: some View {
        SecureField("Password", text: $password)
            .textContentType(.password)
            .submitLabel(.go)
    }
}

#Preview {
    PasswordTextField(password: .constant("Password@123"))
}
