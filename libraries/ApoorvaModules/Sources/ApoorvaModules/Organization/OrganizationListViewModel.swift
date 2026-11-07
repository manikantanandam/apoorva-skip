//
//  OrganizationListViewModel.swift
//  ApoorvaModules
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class OrganizationListViewModel {
    let userRepository: UserRepositoryProtocol

    var organizations: [OrganizationSnapshot] = []
    var selectedOrgId: String?
    var isLoading = false
    var errorMessage: String?

    public init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let user = try await userRepository.getCurrentUser()
            organizations = user.assignedOrgs
            selectedOrgId = user.selectedOrganization?.orgId
        } catch {
            errorMessage = "Unable to load organizations."
        }
    }

    func select(_ organization: OrganizationSnapshot) async -> Bool {
        do {
            let user = try await userRepository.getCurrentUser()
            try await userRepository.updateSelectedOrganization(for: user, organization: organization)
            selectedOrgId = organization.orgId
            return true
        } catch {
            errorMessage = "Unable to switch organization."
            return false
        }
    }
}
