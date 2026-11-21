//
//  UserListViewModel.swift
//  ApoorvaModules
//

import Foundation
import Observation
import ApoorvaModels
import ApoorvaRepository
import ApoorvaServices

@MainActor
@Observable
public class UserListViewModel {
    let userRepository: UserRepositoryProtocol
    private let inviteService: MemberInviteServicing?

    var users: [AppUser] = []
    var pendingInvites: [MemberInvite] = []
    var searchText: String = ""
    var isLoading = false
    var errorMessage: String?
    var currentUserId: String?

    public init(userRepository: UserRepositoryProtocol, inviteService: MemberInviteServicing? = nil) {
        self.userRepository = userRepository
        self.inviteService = inviteService
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
            // Invites are secondary: a failure here shouldn't hide the member list.
            pendingInvites = (try? await inviteService?.pendingInvites(orgId: orgId)) ?? []
        } catch {
            errorMessage = "Unable to load team members."
        }
    }

    func revoke(_ invite: MemberInvite) async {
        do {
            try await inviteService?.revoke(invite)
            pendingInvites.removeAll { $0.id == invite.id }
        } catch {
            errorMessage = "Unable to revoke the invite."
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
