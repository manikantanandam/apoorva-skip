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
    
    func decodeJSON<T: Decodable>(as type: T.Type = T.self) -> T? {
        guard let data = self.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
