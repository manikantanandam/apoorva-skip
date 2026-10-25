//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation

public extension Int {
    var int64Value: Int64 {
        Int64(self)
    }
    
    var string: String {
        return String(describing: self)
    }
    
    var date: Date {
        Date(timeIntervalSince1970: Double(self))
    }
}
