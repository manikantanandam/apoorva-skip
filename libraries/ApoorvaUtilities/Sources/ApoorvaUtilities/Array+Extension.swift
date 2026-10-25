//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 16/10/26.
//

import Foundation

public extension Array where Element: Encodable {
    var string: String {
        let encoder = JSONEncoder()
        
        // Enforces deterministic key ordering
        encoder.outputFormatting = .sortedKeys
        
        guard let encodedData = try? encoder.encode(self),
              let jsonString = String(data: encodedData, encoding: .utf8) else {
            return "[]" // Fallback to empty JSON array string if encoding fails
        }
        return jsonString
    }
}
