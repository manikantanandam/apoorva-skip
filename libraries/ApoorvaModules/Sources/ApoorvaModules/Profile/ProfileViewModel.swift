//
//  ProfileViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class ProfileViewModel {
    
    public var appUser: AppUser?
    let userRepository: UserRepositoryProtocol
    
    var showAlert = false
    var alertMessage: String = ""
    
    public init(userRepository: UserRepositoryProtocol) {
        print("Mani - creating profile view model")
        self.userRepository = userRepository
    }
    
    func checkForUser() async {
            do {
                appUser = try await userRepository.getCurrentUser()
                print("Got the user details in viewmodel \(appUser)")
            } catch {
                print("Unable to get the user details")
            }
    }
    
    func updateSelectedOrganization(orgSnapshot: OrganizationSnapshot) async {
        print("Mani - selected organization \(orgSnapshot)")
        guard let appUser else { return }
        do {
            print("Updating the user")
            try await userRepository.updateSelectedOrganization(
                for: appUser,
                organization: orgSnapshot
            )
            print("Updated the user")
            self.appUser = try userRepository.getUser(id: appUser.id)
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
