//
//  File.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import SwiftUI

public struct CustomTextField: View {
    
    @Binding var text: String
    let placeholder: String
    
    public init(text: Binding<String>, placeholder: String) {
        self._text = text
        self.placeholder = placeholder
    }
    
    public var body: some View {
        TextField(placeholder, text: $text)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }
}

#Preview {
    CustomTextField(
        text: .constant(""),
        placeholder: "Customer Name"
    )
}
