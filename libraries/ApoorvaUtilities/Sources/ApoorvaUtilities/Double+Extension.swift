//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 13/10/26.
//

import Foundation

public extension Double {
    var date: Date {
        Date(timeIntervalSince1970: self)
    }
}
