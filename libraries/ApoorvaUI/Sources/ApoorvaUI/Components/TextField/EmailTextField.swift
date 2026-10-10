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
    private let minHeight: CGFloat
    private let backgroundColor: ApoorvaColor
    
    public init(text: Binding<String>,
                placeholder: String = "Username or Email",
                submitLabel: SubmitLabel = .next,
                keyboardType: UIKeyboardType = .emailAddress,
                textContentType: UITextContentType = .username,
                minHeight: CGFloat = 60,
                backgroundColor: ApoorvaColor = .textFieldBackground
    ) {
        self._text = text
        self.placeholder = placeholder
        self.submitLabel = submitLabel
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.minHeight = minHeight
        self.backgroundColor = backgroundColor
    }
    
    public var body: some View {
        CustomTextField(
            text: $text,
            placeholder: placeholder
        )
        .textContentType(textContentType)
        .keyboardType(keyboardType)
        .submitLabel(submitLabel)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
        .background(backgroundColor.color)
    }
}

#Preview {
    EmailTextField(text: .constant("abc@email.com"))
}
