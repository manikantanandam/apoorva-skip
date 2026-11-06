//
//  ProfileView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import SwiftUI
import ApoorvaUtilities

enum ProfileRoute: Hashable, Identifiable {
    var id: String { UUID().uuidString }
    case selectOrganization
}

public struct ProfileView: View {
    
    @State private var path: [ProfileRoute] = []
    @State private var activeModal: ProfileRoute? = nil
    
    @State var viewModel: ProfileViewModel

    /// Provided only when developer settings are available (debug builds).
    private let developerViewModel: DeveloperSettingsViewModel?

    public init(viewModel: ProfileViewModel,
                developerViewModel: DeveloperSettingsViewModel? = nil) {
        self.viewModel = viewModel
        self.developerViewModel = developerViewModel
    }
    
    public var body: some View {
        NavigationStack(path: $path) {
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
                    .onTapGesture {
                        self.activeModal = .selectOrganization
                    }

                    if let developerViewModel {
                        NavigationLink("Developer") {
                            DeveloperSettingsView(viewModel: developerViewModel)
                        }
                        .padding(.top)
                    }

                    Spacer()
                } else {
                    Text("No User")
                }
            }

        }
        .task {
            await viewModel.checkForUser()
        }
        .sheet(item: $activeModal) { modalRoute in
            // Wrap inside a new NavigationStack to allow navigation INSIDE the modal sheet
            NavigationStack {
                switch modalRoute {
                case .selectOrganization:
                    GenericSelectionView(
                        items: viewModel.assignedOrganizations,
                        onSelect: { organization in
                            Task {
                                await viewModel.updateSelectedOrganization(
                                    orgSnapshot: organization
                                )
                                self.activeModal = nil
                            }
                        }
                    ) { organization in
                        LabelView(text: organization.name)
                            .padding(.vertical, 4)
                    }
                    .navigationTitle("Select Organization")
                }
            
            }
        }
        .alert("", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}
