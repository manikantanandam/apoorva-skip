//
//  InvitationsViewModel.swift
//  ApoorvaModules
//

import Foundation
import Observation
import ApoorvaModels
import ApoorvaServices
import ApoorvaRepository

/// The signed-in user's pending invites. One instance is shared by the Home banner, the More row,
/// the organization switcher and onboarding, so they always agree on the count.
@MainActor
@Observable
public final class InvitationsViewModel {
    public private(set) var invites: [MemberInvite] = []
    var isWorking = false
    var errorMessage: String?
    /// Set after accepting while already in another org, to offer switching to it.
    var acceptedOrganization: OrganizationSnapshot?

    private let inviteService: MemberInviteServicing
    private let authService: AuthServicing
    private let userRepository: UserRepositoryProtocol

    public init(inviteService: MemberInviteServicing, authService: AuthServicing, userRepository: UserRepositoryProtocol) {
        self.inviteService = inviteService
        self.authService = authService
        self.userRepository = userRepository
    }

    public var count: Int { invites.count }

    /// Only a verified email is matched, so nobody can see invites addressed to an address they don't own.
    public func refresh() async {
        guard let account = authService.currentAccount, account.isEmailVerified,
              let email = account.email, !email.isEmpty else {
            invites = []
            return
        }
        // A failed lookup keeps the last known list instead of flashing it empty.
        if let found = try? await inviteService.pendingInvites(forEmail: email) { invites = found }
    }

    func accept(_ invite: MemberInvite) async {
        guard let account = authService.currentAccount else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        let user = try? await userRepository.getCurrentUser()
        let hasCurrentOrg = user?.selectedOrganization != nil
        let name = (user?.name.isEmpty == false ? user?.name : nil) ?? invite.name
        do {
            try await inviteService.accept(invite, account: account, name: name,
                                           existingOrgs: user?.assignedOrgs ?? [], makeCurrent: !hasCurrentOrg,
                                           createProfile: user == nil)
            invites.removeAll { $0.id == invite.id }
            if hasCurrentOrg { acceptedOrganization = OrganizationSnapshot(orgId: invite.orgId, name: invite.orgName) }
        } catch {
            errorMessage = "Couldn't join the shop. Check your connection and try again."
        }
    }

    func decline(_ invite: MemberInvite) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await inviteService.decline(invite)
            invites.removeAll { $0.id == invite.id }
        } catch {
            errorMessage = "Couldn't decline the invite. Try again."
        }
    }

    func switchToAcceptedOrganization() async {
        guard let organization = acceptedOrganization else { return }
        acceptedOrganization = nil
        do {
            let user = try await userRepository.getCurrentUser()
            try await userRepository.updateSelectedOrganization(for: user, organization: organization)
        } catch {
            errorMessage = "Unable to switch organization."
        }
    }
}
