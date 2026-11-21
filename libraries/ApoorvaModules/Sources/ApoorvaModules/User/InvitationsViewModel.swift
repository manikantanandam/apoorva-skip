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
    /// Account the current `invites` belong to, so a different account never sees them.
    private var invitesOwnerUid: String?
    /// Bumped by every refresh and every decision; a lookup that finds it changed discards its result.
    private var refreshToken = 0

    public init(inviteService: MemberInviteServicing, authService: AuthServicing, userRepository: UserRepositoryProtocol) {
        self.inviteService = inviteService
        self.authService = authService
        self.userRepository = userRepository
    }

    public var count: Int { invites.count }

    /// Looks up invites for the signed-in account's verified email. This is a client-side filter only: it limits what
    /// the app asks for, it doesn't stop someone else reading `invites`. Real protection needs Firestore rules.
    public func refresh() async {
        guard let account = authService.currentAccount, account.isEmailVerified,
              let email = account.email, !email.isEmpty else {
            invites = []
            invitesOwnerUid = nil
            return
        }
        let uid = account.uid
        refreshToken += 1
        let token = refreshToken
        let found = try? await inviteService.pendingInvites(forEmail: email)
        // The account changed or a decision landed while the lookup was running: its result is stale.
        guard token == refreshToken, authService.currentAccount?.uid == uid else { return }
        if let found {
            invites = found
            invitesOwnerUid = uid
        } else if invitesOwnerUid != uid {
            // A failed lookup keeps the last list, but never one that belongs to another account.
            invites = []
        }
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
                                           existingOrgs: user?.assignedOrgs ?? [], makeCurrent: !hasCurrentOrg)
            remove(invite)
            if hasCurrentOrg { acceptedOrganization = OrganizationSnapshot(orgId: invite.orgId, name: invite.orgName) }
        } catch MemberInviteError.notPending {
            remove(invite)
            errorMessage = "This invitation is no longer available."
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
            remove(invite)
        } catch {
            errorMessage = "Couldn't decline the invite. Try again."
        }
    }

    /// Switches to a shop the user just joined. The caller passes the organization it read before the alert
    /// dismissed, because dismissing clears `acceptedOrganization`.
    func switchTo(_ organization: OrganizationSnapshot) async {
        acceptedOrganization = nil
        do {
            let user = try await userRepository.getCurrentUser()
            try await userRepository.updateSelectedOrganization(for: user, organization: organization)
        } catch {
            errorMessage = "Unable to switch organization."
        }
    }

    /// Drops a decided invite and invalidates in-flight refreshes that may still contain it.
    private func remove(_ invite: MemberInvite) {
        refreshToken += 1
        invites.removeAll { $0.id == invite.id }
    }
}
