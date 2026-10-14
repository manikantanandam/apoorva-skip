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
    
    func updateSelectedOrganization(
        for user: AppUser,
        organization: OrganizationSnapshot
    ) async throws
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
        guard let user = await userService.currentUser else {
            throw UserError.userNotFound
        }
        return user
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
    
    public func updateSelectedOrganization(
        for user: AppUser,
        organization: OrganizationSnapshot
    ) async throws {
        try await userService.updateSelectedOrganization(
            for: user,
            organization: organization
        )
        print("Remote update successful")
        let updatedUser = user.copyWith(selectedOrganization: organization)
        try userDefaults.set(updatedUser, forKey: key(for: user.id))
    }
}

private extension UserRepository {
    func key(for id: String) -> String {
        return "user_\(id)"
    }
}
