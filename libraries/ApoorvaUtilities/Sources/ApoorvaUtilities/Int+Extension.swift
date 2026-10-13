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
}
