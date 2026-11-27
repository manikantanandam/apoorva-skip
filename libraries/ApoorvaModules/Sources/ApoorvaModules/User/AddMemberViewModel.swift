//
//  AddMemberViewModel.swift
//  ApoorvaModules
//

import Foundation
import SkipFuse
import Observation
import ApoorvaModels
import ApoorvaServices
import ApoorvaRepository

@MainActor
@Observable
public final class AddMemberViewModel {
    var email = ""
    var name = ""
    var role: OrgRole = .cashier
    var selectedStoreIds: Set<String>
    var isSaving = false
    var errorMessage: String?

    let stores: [Store]
    private let inviteService: MemberInviteServicing
    private let userRepository: UserRepositoryProtocol
    private let memberRepository: any OrgCollectionRepositoryProtocol<Member>

    public init(inviteService: MemberInviteServicing, userRepository: UserRepositoryProtocol,
                memberRepository: any OrgCollectionRepositoryProtocol<Member>, stores: [Store]) {
        self.inviteService = inviteService
        self.userRepository = userRepository
        self.memberRepository = memberRepository
        self.stores = stores
        self.selectedStoreIds = Set(stores.first.map { [$0.id] } ?? [Store.defaultId])
    }

    var canSend: Bool {
        MemberInvite.isValid(email: email) && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !selectedStoreIds.isEmpty && !isSaving
    }

    func toggleStore(_ id: String) {
        if selectedStoreIds.contains(id) { selectedStoreIds.remove(id) } else { selectedStoreIds.insert(id) }
    }

    /// Returns true when the invite was saved.
    func send() async -> Bool {
        guard canSend else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let user = try await userRepository.getCurrentUser()
            guard let organization = user.selectedOrganization else {
                errorMessage = "Choose an organization first."
                return false
            }
            let normalized = MemberInvite.normalize(email: email)
            if normalized == MemberInvite.normalize(email: user.email) {
                errorMessage = "That's your own email."
                return false
            }
            let members = (try? await memberRepository.all()) ?? []
            if members.contains(where: { MemberInvite.normalize(email: $0.email) == normalized && $0.isActive }) {
                errorMessage = "This person is already a member."
                return false
            }
            let invite = MemberInvite(orgId: organization.orgId, orgName: organization.name, email: normalized,
                                      name: name.trimmingCharacters(in: .whitespaces), role: role,
                                      storeIds: stores.map(\.id).filter(selectedStoreIds.contains),
                                      invitedBy: user.id, invitedByName: user.name)
            try inviteService.send(invite)
            return true
        } catch {
            errorMessage = "Couldn't send the invite. Check your connection and try again."
            return false
        }
    }
}
