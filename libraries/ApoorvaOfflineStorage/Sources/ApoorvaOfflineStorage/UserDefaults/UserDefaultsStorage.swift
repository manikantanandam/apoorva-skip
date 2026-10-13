//
//  UserDefaultsStorage.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation

public protocol UserDefaultsStorageProtocol: Sendable {
    func set<T: Encodable>(_ object: T, forKey key: String) throws
    func get<T: Decodable>(forKey key: String, as type: T.Type) throws -> T?
    func remove(forKey key: String)
}

public final class UserDefaultsStorage: @unchecked UserDefaultsStorageProtocol {
    private let defaults: UserDefaults
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    public func set<T: Encodable>(_ object: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(object)
        defaults.set(data, forKey: key)
    }
    
    public func get<T: Decodable>(forKey key: String, as type: T.Type) throws -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }
    
    public func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}
