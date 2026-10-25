//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Foundation

public extension Int64 {
    var intValue: Int { Int(self) }
    
    var date: Date {
        Date(timeIntervalSince1970: Double(self))
    }
    
    var optionalBoolValue: Bool? {
        switch self {
        case 0:
            return false
        case 1:
            return true
        default:
            return nil
        }
    }
    
    var boolValue: Bool {
        optionalBoolValue ?? false
    }
    
}
