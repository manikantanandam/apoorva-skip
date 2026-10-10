//
//  File.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import SwiftUI

public struct CustomButton: View {
    
    let text: String
    let icon: ApoorvaIcon?
    let action: () -> Void
    let needLoader: Bool
    private let minHeight: CGFloat
    let backgroundColor: ApoorvaColor
    let textColor: ApoorvaColor
    @State private var isLoading: Bool = false
    
    public init(text: String,
                icon: ApoorvaIcon? = nil,
                needLoader: Bool = false,
                minHeight: CGFloat = 60,
                backgroundColor: ApoorvaColor = .systemBackGround,
                textColor: ApoorvaColor = .buttonTextColor,
                action: @escaping () -> Void) {
        self.text = text
        self.icon = icon
        self.action = action
        self.needLoader = needLoader
        self.backgroundColor = backgroundColor
        self.minHeight = minHeight
        self.textColor = textColor
    }
    
    public var body: some View {
        HStack {
            if isLoading {
                CircularLoadingView()
            } else {
                Text(text)
                    .foregroundStyle(textColor.color)
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
        .background(backgroundColor.color)
        .onTapGesture {
            guard !isLoading else { return }
            isLoading = true
            action()
        }
    }
}
