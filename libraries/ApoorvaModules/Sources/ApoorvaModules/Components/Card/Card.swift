//
//  Card.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import SwiftUI

struct CardView<Content: View>: View {
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let content: () -> Content
    
    // Provide sensible default parameters
    init(
        backgroundColor: Color = .white,
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 6,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.content = content
    }
    
    var body: some View {
        content()
            .padding()
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 4)
    }
}
