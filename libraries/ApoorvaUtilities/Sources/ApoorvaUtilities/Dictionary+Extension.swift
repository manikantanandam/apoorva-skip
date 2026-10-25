//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 16/10/26.
//

import Foundation

public extension Dictionary where Key: Encodable, Value: Encodable {
    var string: String {
        guard let encodedData = try? JSONEncoder().encode(self),
              let jsonString = String(data: encodedData, encoding: .utf8) else {
            return "{}" // Fallback to empty JSON object string if encoding fails
        }
        return jsonString
    }
}
