//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation

public extension Bool {
    var stringValue: String {
        switch self {
        case true: "true"
        case false: "false"
        }
    }
}
