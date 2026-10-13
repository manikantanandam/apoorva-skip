//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation

public extension String {
    var boolValue: Bool? {
        switch self {
        case "false": false
        case "true": true
        default: nil
        }
    }
    
    func boolValue(defaultValue: Bool) -> Bool {
        boolValue ?? defaultValue
    }
}
