//
//  IconTextField.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 10/10/26.
//

import SwiftUI

struct IconTextField: View {
    
    @Binding var text: String
    let placeholder: String
    let icon: ApoorvaIcon
    let iconSize: CGFloat
    let submitLabel: SubmitLabel
    
    var body: some View {
        HStack {
            Image(systemName: icon.rawValue)
                .font(.system(size: iconSize))
                .foregroundStyle(.pink)
            CustomTextField(text: $text, placeholder: placeholder)
                .keyboardType(.alphabet)
                .submitLabel(submitLabel)
        }
    }
}

#Preview {
    IconTextField(
        text: .constant(""),
        placeholder: "Customer Name",
        icon: .person,
        iconSize: 24,
        submitLabel: .next
    )
}
