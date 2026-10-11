//
//  ProfileView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import SwiftUI

public struct ProfileView: View {
    
    @State var viewModel: ProfileViewModel
    
    public init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            VStack {
                if let user = viewModel.appUser {
                    Text(user.name)
                    Text(user.email)
                    Text(user.role.rawValue)
                    Text(user.status)
                    Text("\(user.createdAt.timeIntervalSince1970)")
                    Text("\(user.updatedAt.timeIntervalSince1970)")
                    Spacer()
                } else {
                    Text("No User")
                }
            }

        }
        .task {
            viewModel.checkForUser()
        }
    }
}
