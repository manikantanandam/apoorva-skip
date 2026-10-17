//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation
import SwiftUI

enum CardStatStyle {
    case info
    case headline
    
    var title: Font.TextStyle {
        switch self {
        case .info:
            return .body
        case .headline:
            return .caption
        }
    }
    
    var titleFont: Font.TextStyle {
        switch self {
        case .info:
            return .caption
        case .headline:
            return .body
        }
    }
    
    var valueFont: Font.TextStyle {
        switch self {
        case .info:
            return .body
        case .headline:
            return .title
        }
    }

}

struct CardStatView: View {
    let title: String
    let value: String
    
    let style: CardStatStyle
    
    init(title: String, value: String, style: CardStatStyle = .headline) {
        self.title = title
        self.value = value
        self.style = style
    }
    
    var body: some View {
        CardView {
            VStack {
                LabelView(text: title, style: style.titleFont)
                Spacer()
                LabelView(text: value, style: style.valueFont)
            }
        }
    }
}
