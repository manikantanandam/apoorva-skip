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
    /// Set when the member list loaded but the pending invitations didn't, so an empty section isn't mistaken for "none".
    var invitesLoadFailed = false
    var currentUserId: String?
    /// Organization the list is for, to show each person's role in it.
    private(set) var organizationId: String?

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

    /// Pending invitations matching the search text (name or email), like the member list.
    var filteredInvites: [MemberInvite] {
        guard !searchText.isEmpty else { return pendingInvites }
        let query = searchText.lowercased()
        return pendingInvites.filter {
            $0.name.lowercased().contains(query) || $0.email.lowercased().contains(query)
        }
    }

    /// The person's role in this organization: the per-org entry if there is one, else the legacy role.
    func role(of user: AppUser) -> OrgRole {
        guard let organizationId else { return OrgRole(appRole: user.role) }
        return user.member(in: organizationId).role
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
            organizationId = orgId
            users = try await userRepository.listUsers(orgId: orgId)
            await loadInvites()
        } catch {
            errorMessage = "Unable to load team members."
        }
    }

    /// Invites are secondary: a failure here keeps the member list and is reported separately, with a retry.
    func loadInvites() async {
        guard let organizationId, let inviteService else { return }
        do {
            pendingInvites = try await inviteService.pendingInvites(orgId: organizationId)
            invitesLoadFailed = false
        } catch {
            invitesLoadFailed = true
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
            var membership = user.orgMembership
            // A per-org role overrides the legacy one, so an edit must update it too or it would have no effect.
            if let organizationId, membership[organizationId]?.role != nil {
                let orgRole = OrgRole(appRole: role)
                try await inviteService?.updateMembershipRole(userId: user.id, orgId: organizationId, role: orgRole)
                membership[organizationId]?.role = orgRole
            }
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index] = user.copyWith(role: role, orgMembership: membership)
            }
        } catch {
            errorMessage = "Unable to update role."
        }
    }
}
