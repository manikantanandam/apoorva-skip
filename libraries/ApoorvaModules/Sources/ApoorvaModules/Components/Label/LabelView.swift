//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 11/10/26.
//

import Foundation
import SwiftUI

public struct LabelView: View {
    
    private let text: String
    private let style: Font.TextStyle
    
    public init(text: String,
                style: Font.TextStyle = .body) {
        self.text = text
        self.style = style
    }
    
    public var body: some View {
        Text(text)
            .font(.system(style))
    }
}
