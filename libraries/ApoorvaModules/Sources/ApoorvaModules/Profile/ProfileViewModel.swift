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

@MainActor
@Observable
public class ProfileViewModel {

    public var appUser: AppUser?
    let userRepository: UserRepositoryProtocol
    private let authService: AuthServicing
    private let clearLocalData: () -> Void

    var showAlert = false
    var alertMessage: String = ""

    public init(userRepository: UserRepositoryProtocol,
                authService: AuthServicing,
                clearLocalData: @escaping () -> Void) {
        self.userRepository = userRepository
        self.authService = authService
        self.clearLocalData = clearLocalData
    }

    func logoutPressed() {
        do {
            try authService.logout()
            clearLocalData()
        } catch {
            print("Error \(error)")
        }
    }
    
    func checkForUser() async {
            do {
                appUser = try await userRepository.getCurrentUser()
            } catch {
                print("Unable to get the user details")
            }
    }
    
    func updateSelectedOrganization(orgSnapshot: OrganizationSnapshot) async {
        print("Mani - selected organization \(orgSnapshot)")
        guard let appUser else { return }
        do {
            try await userRepository.updateSelectedOrganization(
                for: appUser,
                organization: orgSnapshot
            )
            self.appUser = try await userRepository.getUser(id: appUser.id)
        } catch let error {
            print("Error in updating user")
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
