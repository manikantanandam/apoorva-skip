//
//  ProfileView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import SwiftUI
import ApoorvaUtilities
import ManiSwiftUIComponents

public struct ProfileView: View {
    @Environment(\.maniTheme) private var theme

    @State var viewModel: ProfileViewModel

    private let onSelectOrganization: () -> Void
    private let onShowOrganizations: () -> Void
    private let onShowTeamMembers: () -> Void
    /// Provided only when developer settings are available (debug builds).
    private let onShowDeveloperSettings: (() -> Void)?

    public init(viewModel: ProfileViewModel,
                onSelectOrganization: @escaping () -> Void,
                onShowOrganizations: @escaping () -> Void,
                onShowTeamMembers: @escaping () -> Void,
                onShowDeveloperSettings: (() -> Void)?) {
        self.viewModel = viewModel
        self.onSelectOrganization = onSelectOrganization
        self.onShowOrganizations = onShowOrganizations
        self.onShowTeamMembers = onShowTeamMembers
        self.onShowDeveloperSettings = onShowDeveloperSettings
    }

    public var body: some View {
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
                        action: onSelectOrganization
                    )

                    Button(action: onShowOrganizations) {
                        ManiListRow(title: "Organizations")
                    }

                    if viewModel.canManageUsers {
                        Button(action: onShowTeamMembers) {
                            ManiListRow(title: "Team Members")
                        }
                    }

                    if let onShowDeveloperSettings {
                        Button(action: onShowDeveloperSettings) {
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
        .task {
            await viewModel.checkForUser()
        }
        .alert("", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}
