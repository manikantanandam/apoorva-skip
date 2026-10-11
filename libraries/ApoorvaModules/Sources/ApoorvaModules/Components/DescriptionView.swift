//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 11/10/26.
//

import SwiftUI

struct DescriptionView: View {
    let title: String
    let value: String
    let navigationAllowed: Bool
    let iconColor: ApoorvaColor
    
    init(title: String,
         value: String,
         navigationAllowed: Bool = false,
         iconColor: ApoorvaColor = .iconColor) {
        self.title = title
        self.value = value
        self.navigationAllowed = navigationAllowed
        self.iconColor = iconColor
    }
    public var body: some View {
        CardView() {
            HStack {
                LabelView(text: title)
                Spacer()
                LabelView(text: value)
                if navigationAllowed {
                    IconView(icon: .rightArrow, iconSize: 24, color: iconColor.color)
                }
            }
        }
    }
}
