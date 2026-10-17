//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation

public enum SortType {
    case ascending
    case descending
}

public extension SortType {
    var togglevalue: SortType {
        switch self {
        case .ascending:
            return .descending
        case .descending:
            return .ascending
        }
    }
}
