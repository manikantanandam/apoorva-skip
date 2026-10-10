//
//  File.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import SwiftUI

public enum ApoorvaColor {
    case systemBackGround
    case textFieldBackground
    case buttonBackground
    case orange
    case buttonTextColor
    case textColor
    case iconColor
    
    public var color: Color {
        switch self {
        case .systemBackGround:
            return Color(uiColor: UIColor.systemBackground)
        case .orange:
            return Color.orange
        case .textFieldBackground:
            return Color(uiColor: UIColor(red: 241/255, green: 243/255, blue: 246/255, alpha: 1))
        case .buttonTextColor:
            return Color.white
        case .textColor:
            return Color.black
        case .iconColor:
            return Color(uiColor: UIColor(red: 125/255, green: 143/255, blue: 155/255, alpha: 1))
        case .buttonBackground:
            return .orange
        }
    }
}
