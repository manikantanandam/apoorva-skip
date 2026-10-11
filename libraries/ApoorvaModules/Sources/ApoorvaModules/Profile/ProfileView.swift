//
//  ProfileView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import SwiftUI
import ApoorvaUtilities

public struct ProfileView: View {
    
    @State var viewModel: ProfileViewModel
    
    public init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                if let user = viewModel.appUser {
                    HStack {
                        AvatarView(imageURL: user.imageURL)
                        VStack(alignment: .leading) {
                            LabelView(text: user.name)
                            LabelView(text: user.email)
                        }
                    }
                    
                    DescriptionView(title: "Role", value: user.role.rawValue)
                    DescriptionView(title: "Status", value: user.status)
                    
                    DescriptionView(title: "Created At",
                                    value: viewModel.createdAt)
                    DescriptionView(title: "updated At",
                                    value: viewModel.updatedAt)
                    
                    DescriptionView(title: "Organization",
                                    value: viewModel.currentOrganization,
                                    navigationAllowed: true)
                    
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
