//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import SwiftUI

public struct CustomTextField: View {
    
    @Binding var text: String
    let placeholder: String
    let padding: CGFloat
    let backgroundColor: ApoorvaColor
    
    public init(text: Binding<String>,
                placeholder: String,
                padding: CGFloat = 16,
                backgroundColor: ApoorvaColor = .textFieldBackground) {
        self._text = text
        self.placeholder = placeholder
        self.padding = padding
        self.backgroundColor = backgroundColor
    }
    
    public var body: some View {
        TextField(placeholder, text: $text)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, padding)
    }
}

#Preview {
    CustomTextField(
        text: .constant(""),
        placeholder: "Customer Name",
        padding: 12
    )
}
