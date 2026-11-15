//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
            #if canImport(UIKit)
            return Color(uiColor: UIColor.systemBackground)
            #else
            return Color.white  // No UIColor on Android; no dark-mode adaptation yet.
            #endif
        case .orange:
            return Color.orange
        case .textFieldBackground:
            return Color(red: 241/255, green: 243/255, blue: 246/255)
        case .buttonTextColor:
            return Color.white
        case .textColor:
            return Color.black
        case .iconColor:
            return Color(red: 125/255, green: 143/255, blue: 155/255)
        case .buttonBackground:
            return .orange
        }
    }
}
