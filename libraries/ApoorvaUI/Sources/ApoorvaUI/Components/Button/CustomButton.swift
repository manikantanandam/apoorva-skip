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
    let backgroundColor: ApoorvaColor
    @State private var isLoading: Bool = false
    
    public init(text: String,
                icon: ApoorvaIcon? = nil,
                needLoader: Bool = false,
                backgroundColor: ApoorvaColor = .systemBackGround,
                action: @escaping () -> Void) {
        self.text = text
        self.icon = icon
        self.action = action
        self.needLoader = needLoader
        self.backgroundColor = backgroundColor
    }
    
    public var body: some View {
        HStack {
            if isLoading {
                CircularLoadingView()
            } else {
                Text(text)
            }
        }
        .onTapGesture {
            guard !isLoading else { return }
            isLoading = true
            action()
        }
    }
}
