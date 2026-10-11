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
    
    public init(userRepository: UserRepositoryProtocol) {
        print("Mani - creating profile view model")
        self.userRepository = userRepository
    }
    
    func checkForUser() {
        Task {
            do {
                appUser = try await userRepository.getCurrentUser()
                print("Got the user details in viewmodel \(appUser)")
            } catch {
                print("Unable to get the user details")
            }
            
        }
    }
    
}
