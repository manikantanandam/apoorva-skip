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
        self.userRepository = userRepository
        checkForUser()
    }
    
    func checkForUser() {
        Task {
            do {
                appUser = try await userRepository.getCurrentUser()
                print("Got the user details")
            } catch {
                print("Unable to get the user details")
            }
            
        }
    }
    
}
