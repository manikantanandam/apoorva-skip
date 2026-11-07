//
//  UserListViewModel.swift
//  ApoorvaModules
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class UserListViewModel {
    let userRepository: UserRepositoryProtocol

    var users: [AppUser] = []
    var searchText: String = ""
    var isLoading = false
    var errorMessage: String?
    var currentUserId: String?

    public init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }

    var filteredUsers: [AppUser] {
        guard !searchText.isEmpty else { return users }
        let query = searchText.lowercased()
        return users.filter {
            $0.name.lowercased().contains(query) || $0.email.lowercased().contains(query)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let currentUser = try await userRepository.getCurrentUser()
            currentUserId = currentUser.id
            guard let orgId = currentUser.selectedOrganization?.orgId else {
                users = []
                return
            }
            users = try await userRepository.listUsers(orgId: orgId)
        } catch {
            errorMessage = "Unable to load team members."
        }
    }

    func updateRole(for user: AppUser, role: AppUserRole) async {
        do {
            try await userRepository.updateUserRole(id: user.id, role: role)
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index] = user.copyWith(role: role)
            }
        } catch {
            errorMessage = "Unable to update role."
        }
    }
}
