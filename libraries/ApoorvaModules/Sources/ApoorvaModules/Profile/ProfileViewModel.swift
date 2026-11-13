//
//  ProfileViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaModels
import ApoorvaRepository
import ApoorvaServices
import ManiLogger

private let logger = AppLogger(category: .ui)

@MainActor
@Observable
public class ProfileViewModel {

    public var appUser: AppUser?
    let userRepository: UserRepositoryProtocol
    private let authService: AuthServicing
    private let clearLocalData: () async -> Void

    var showAlert = false
    var alertMessage: String = ""

    public init(userRepository: UserRepositoryProtocol,
                authService: AuthServicing,
                clearLocalData: @escaping () async -> Void) {
        self.userRepository = userRepository
        self.authService = authService
        self.clearLocalData = clearLocalData
    }

    func logoutPressed() async {
        do {
            try authService.logout()
            await clearLocalData()
        } catch {
            logger.error("Profile load failed: \(error)")
        }
    }
    
    func checkForUser() async {
            do {
                appUser = try await userRepository.getCurrentUser()
            } catch {
                logger.error("Unable to get the user details")
            }
    }
    
    func updateSelectedOrganization(orgSnapshot: OrganizationSnapshot) async {
        logger.info("Selected organization changed")
        guard let appUser else { return }
        do {
            try await userRepository.updateSelectedOrganization(
                for: appUser,
                organization: orgSnapshot
            )
            self.appUser = try await userRepository.getUser(id: appUser.id)
        } catch let error {
            logger.error("Error in updating user")
            self.alertMessage = error.localizedDescription
            self.showAlert = true
        }
    }
}

public extension ProfileViewModel {
    var currentOrganization: String {
        guard let selectedOrganization = appUser?.selectedOrganization else {
            return "Not assigned"
        }
        
        return selectedOrganization.name
    }
    
    var createdAt: String {
        guard let appUser else { return "" }
        return appUser.createdAt.toString(format: "dd-MM-yyyy")
    }
    
    var updatedAt: String {
        guard let appUser else { return "" }
        return appUser.updatedAt.toString(format: "dd-MM-yyyy")
    }
    
    var assignedOrganizations: [OrganizationSnapshot] {
        guard let appUser else { return [] }
        return appUser.assignedOrgs

    }
}
