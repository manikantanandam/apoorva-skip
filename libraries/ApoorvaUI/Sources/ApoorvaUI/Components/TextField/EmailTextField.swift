//
//  SwiftUIView.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 04/10/26.
//

import SwiftUI

public struct EmailTextField: View {
    
    @Binding private var text: String
    private let placeholder: String
    private let submitLabel: SubmitLabel
    private let keyboardType: UIKeyboardType
    private let textContentType: UITextContentType
    
    public init(text: Binding<String>,
                placeholder: String = "Username or Email",
                submitLabel: SubmitLabel = .next,
                keyboardType: UIKeyboardType = .emailAddress,
                textContentType: UITextContentType = .username) {
        self._text = text
        self.placeholder = placeholder
        self.submitLabel = submitLabel
        self.keyboardType = keyboardType
        self.textContentType = textContentType
    }
    
    public var body: some View {
        CustomTextField(
            text: $text,
            placeholder: placeholder
        )
        .textContentType(textContentType)
        .keyboardType(keyboardType)
        .submitLabel(submitLabel)
    }
}

#Preview {
    EmailTextField(text: .constant("abc@email.com"))
}
