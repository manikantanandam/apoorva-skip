//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation

public extension Int64 {
    var intValue: Int { Int(self) }
    
    var date: Date {
        Date(timeIntervalSince1970: Double(self))
    }
    
    var boolValue: Bool {
        return self == 1
    }
}


public extension Int {
    var int64Value: Int64 {
        Int64(self)
    }
    
    var string: String {
        return String(describing: self)
    }
}
