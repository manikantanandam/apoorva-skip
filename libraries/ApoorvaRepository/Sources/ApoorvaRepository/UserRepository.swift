//
//  File.swift
//  ApoorvaRepository
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaModels
import ApoorvaOfflineStorage
import ApoorvaServices

enum UserError: Error {
    case notAuthenticated
    case userNotFound
}

public protocol UserRepositoryProtocol: Sendable {
    
    func getCurrentUser() async throws -> AppUser
    
    func getUser(id: String) throws -> AppUser?
    
    func setUser(user: AppUser) throws
    
    func updateUser(user: AppUser) throws
    
    func deleteUser(id: String)
}


public final class UserRepository: UserRepositoryProtocol {
    
    let userDefaults: UserDefaultsStorageProtocol
    let authService: AuthServicing
    let userService: UserServiceProtocol
    
    public init(
        userDefaults: UserDefaultsStorageProtocol,
        authService: AuthServicing,
        userService: UserServiceProtocol
    ) {
        self.userDefaults = userDefaults
        self.authService = authService
        self.userService = userService
        print("Mani - user repository init")
    }
    
    public func getCurrentUser() async throws -> AppUser {
        for await user in await userService.userSessionStream {
            print("user is received in repository")
            guard let user else {
                break
            }
            return user
        }
        
        throw UserError.userNotFound
    }
    
    public func getUser(id: String) throws -> AppUser? {
        try userDefaults.get(forKey: key(for: id), as: AppUser.self)
    }
    
    public func setUser(user: AppUser) throws {
        try userDefaults.set(user, forKey: key(for: user.id))
    }
    
    public func updateUser(user: AppUser) throws {
        try userDefaults.set(user, forKey: key(for: user.id))
    }
    
    public func deleteUser(id: String) {
        userDefaults.remove(forKey: key(for: id))
    }
    
    func key(for id: String) -> String {
        return "user_\(id)"
    }
}
