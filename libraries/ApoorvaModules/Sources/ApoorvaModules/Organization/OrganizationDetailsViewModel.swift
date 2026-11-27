//
//  OrganizationDetailsViewModel.swift
//  ApoorvaModules
//

import Foundation
import SkipFuse
import Observation
import ApoorvaModels
import ApoorvaRepository
import ApoorvaServices

/// Everything about the selected organization on one screen: the org doc, its settings, plan, stores, accounts and team.
@MainActor
@Observable
public final class OrganizationDetailsViewModel {
    let session: AppSession
    var organization: Organization?
    var members: [Member] = []
    var pendingInvites: [MemberInvite] = []
    var isLoading = false
    var errorMessage: String?

    private let organizationRepository: OrganizationRepositoryProtocol
    private let memberRepository: any OrgCollectionRepositoryProtocol<Member>
    private let inviteService: MemberInviteServicing

    public init(session: AppSession, organizationRepository: OrganizationRepositoryProtocol,
                memberRepository: any OrgCollectionRepositoryProtocol<Member>, inviteService: MemberInviteServicing) {
        self.session = session
        self.organizationRepository = organizationRepository
        self.memberRepository = memberRepository
        self.inviteService = inviteService
    }

    var settings: OrgSettings { session.settings }
    var stores: [Store] { session.stores }
    var planStatus: PlanStatus { session.planStatus }

    /// Active members, owners first, then by name.
    var activeMembers: [Member] {
        members.filter { $0.isActive && !$0.isDeleted }
            .sorted { ($0.role == .owner ? 0 : 1, $0.name) < ($1.role == .owner ? 0 : 1, $1.name) }
    }

    func load() async {
        guard let orgId = session.user?.selectedOrganization?.orgId else {
            errorMessage = "No organization selected."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            organization = try await organizationRepository.getOrganization(orgId: orgId)
        } catch {
            errorMessage = "Unable to load organization details."
        }
        members = (try? await memberRepository.all()) ?? []
        pendingInvites = (try? await inviteService.pendingInvites(orgId: orgId)) ?? []
    }
}
