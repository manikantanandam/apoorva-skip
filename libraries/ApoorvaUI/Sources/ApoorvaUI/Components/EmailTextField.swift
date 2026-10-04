//
//  SwiftUIView.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 04/10/26.
//

import SwiftUI

struct EmailTextField: View {
    
    @Binding var text: String
    
    var body: some View {
        TextField("Username or Email", text: $text)
            .textContentType(.username)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.next) // Changes keyboard button to "Next"
    }
}

#Preview {
    EmailTextField(text: .constant("abc@email.com"))
}
