//
//  IconTextField.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import SwiftUI

public struct IconTextField: View {
    
    @Binding var text: String
    private let placeholder: String
    private let icon: ApoorvaIcon
    private let iconSize: CGFloat
    private let submitLabel: SubmitLabel
    private let minHeight: CGFloat
    private let backgroundColor: ApoorvaColor
    private let iconColor: ApoorvaColor
    
    public init(text: Binding<String>,
                placeholder: String,
                icon: ApoorvaIcon,
                submitLabel: SubmitLabel = .next,
                iconSize: CGFloat = 24,
                minHeight: CGFloat = 60,
                backgroundColor: ApoorvaColor = .textFieldBackground,
                iconColor: ApoorvaColor = .iconColor
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.submitLabel = submitLabel
        self.minHeight = minHeight
        self.backgroundColor = backgroundColor
        self.iconSize = iconSize
        self.iconColor = iconColor
    }
    
    public var body: some View {
        HStack {
            Image(systemName: icon.rawValue)
                .font(.system(size: iconSize))
                .foregroundStyle(iconColor.color)
                .padding(.leading, 16)
            CustomTextField(
                text: $text,
                placeholder: placeholder,
            )
            .keyboardType(.alphabet)
            .submitLabel(submitLabel)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
        .background(backgroundColor.color)
    }
}

#Preview {
    IconTextField(
        text: .constant(""),
        placeholder: "Customer Name",
        icon: .person
    )
}
