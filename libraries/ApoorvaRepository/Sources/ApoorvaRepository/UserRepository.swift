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
    
    func getUser(id: String) async throws -> AppUser?
    
    func setUser(user: AppUser) async throws
    
    func updateUser(user: AppUser) async throws
    
    func deleteUser(id: String) async
    
    func updateSelectedOrganization(
        for user: AppUser,
        organization: OrganizationSnapshot
    ) async throws

    func listUsers(orgId: String) async throws -> [AppUser]

    func updateUserRole(id: String, role: AppUserRole) async throws

    /// Demo shop: returns this user (with no org) so every repository stays local-only.
    func setDemoUser(_ user: AppUser?) async
}

public extension UserRepositoryProtocol {
    func setDemoUser(_ user: AppUser?) async {}
}


public final actor UserRepository: UserRepositoryProtocol {
    
    let userDefaults: UserDefaultsStorageProtocol
    let authService: AuthServicing
    let userService: UserServiceProtocol
    private var demoUser: AppUser?

    public func setDemoUser(_ user: AppUser?) {
        demoUser = user
    }

    public init(
        userDefaults: UserDefaultsStorageProtocol,
        authService: AuthServicing,
        userService: UserServiceProtocol
    ) {
        self.userDefaults = userDefaults
        self.authService = authService
        self.userService = userService
    }
    
    public func getCurrentUser() async throws -> AppUser {
        if let demoUser { return demoUser }
        guard let user = await userService.currentUser else {
            throw UserError.userNotFound
        }
        return user
    }
    
    public func getUser(id: String) async throws -> AppUser? {
        try userDefaults.get(forKey: key(for: id), as: AppUser.self)
    }
    
    public func setUser(user: AppUser) async throws {
        try userDefaults.set(user, forKey: key(for: user.id))
    }
    
    public func updateUser(user: AppUser) async throws {
        try userDefaults.set(user, forKey: key(for: user.id))
    }
    
    public func deleteUser(id: String) async {
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

    public func listUsers(orgId: String) async throws -> [AppUser] {
        try await userService.listUsers(orgId: orgId)
    }

    public func updateUserRole(id: String, role: AppUserRole) async throws {
        try await userService.updateRole(userId: id, role: role)
    }
}

private extension UserRepository {
    func key(for id: String) -> String {
        return "user_\(id)"
    }
}
