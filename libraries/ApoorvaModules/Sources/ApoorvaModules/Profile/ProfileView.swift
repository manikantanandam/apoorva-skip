//
//  ProfileView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import SwiftUI
import ApoorvaUtilities
import ManiSwiftUIComponents

enum ProfileRoute: Hashable, Identifiable {
    var id: String { UUID().uuidString }
    case selectOrganization
}

public struct ProfileView: View {
    @Environment(\.maniTheme) private var theme

    @State private var path: [ProfileRoute] = []
    @State private var activeModal: ProfileRoute? = nil
    
    @State var viewModel: ProfileViewModel

    /// Provided only when developer settings are available (debug builds).
    private let developerViewModel: DeveloperSettingsViewModel?
    private let makeUserListViewModel: () -> UserListViewModel
    private let makeOrganizationListViewModel: () -> OrganizationListViewModel

    public init(viewModel: ProfileViewModel,
                developerViewModel: DeveloperSettingsViewModel? = nil,
                makeUserListViewModel: @escaping () -> UserListViewModel,
                makeOrganizationListViewModel: @escaping () -> OrganizationListViewModel) {
        self.viewModel = viewModel
        self.developerViewModel = developerViewModel
        self.makeUserListViewModel = makeUserListViewModel
        self.makeOrganizationListViewModel = makeOrganizationListViewModel
    }
    
    public var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: ManiSpacing.lg) {
                if let user = viewModel.appUser {
                    HStack(spacing: ManiSpacing.md) {
                        ManiAvatar(imageURL: user.imageURL, size: 60)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name)
                                .font(theme.typography.body.weight(.semibold))
                                .foregroundStyle(theme.base.text)
                            Text(user.email)
                                .font(theme.typography.secondary)
                                .foregroundStyle(theme.base.textSecondary)
                        }
                    }

                    ManiCard {
                        VStack(spacing: ManiSpacing.sm) {
                            ManiBreakdownRow(label: "Role", value: user.role.rawValue)
                            ManiBreakdownRow(label: "Status", value: user.status)
                            ManiBreakdownRow(label: "Created At", value: viewModel.createdAt)
                            ManiBreakdownRow(label: "Updated At", value: viewModel.updatedAt)
                        }
                    }

                    ManiListRow(
                        title: "Organization",
                        value: viewModel.currentOrganization,
                        action: { self.activeModal = .selectOrganization }
                    )

                    NavigationLink {
                        OrganizationListView(viewModel: makeOrganizationListViewModel())
                    } label: {
                        ManiListRow(title: "Organizations")
                    }

                    if viewModel.canManageUsers {
                        NavigationLink {
                            UserListView(viewModel: makeUserListViewModel())
                        } label: {
                            ManiListRow(title: "Team Members")
                        }
                    }

                    if let developerViewModel {
                        NavigationLink {
                            DeveloperSettingsView(viewModel: developerViewModel)
                        } label: {
                            ManiListRow(title: "Developer")
                        }
                    }

                    ManiButton("Logout", kind: .outline) {
                        viewModel.logoutPressed()
                    }

                    Spacer()
                } else {
                    ManiNote("No user signed in.", kind: .warning)
                }
            }
            .padding(ManiSpacing.lg)
            .background(theme.base.background.ignoresSafeArea())
        }
        .task {
            await viewModel.checkForUser()
        }
        .sheet(item: $activeModal, onDismiss: {
            Task { await viewModel.checkForUser() }
        }) { modalRoute in
            // Wrap inside a new NavigationStack to allow navigation INSIDE the modal sheet
            NavigationStack {
                switch modalRoute {
                case .selectOrganization:
                    OrganizationListView(viewModel: makeOrganizationListViewModel())
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
