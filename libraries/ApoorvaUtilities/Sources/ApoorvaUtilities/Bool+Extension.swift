//
//  Bool+Extension.swift
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
    
    var intValue: Int {
        switch self {
        case true: 1
        case false: 0
        }
    }
    
    var int64Value: Int64 {
        Int64(intValue)
    }
}
