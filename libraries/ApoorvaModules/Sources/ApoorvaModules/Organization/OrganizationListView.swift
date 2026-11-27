//
//  OrganizationListView.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct OrganizationListView: View {
    @Environment(\.maniTheme) var theme
    @Bindable var viewModel: OrganizationListViewModel
    private let invitations: InvitationsViewModel?

    public init(viewModel: OrganizationListViewModel, invitations: InvitationsViewModel? = nil) {
        self.viewModel = viewModel
        self.invitations = invitations
    }

    public var body: some View {
        VStack(spacing: 0) {
            ManiAppBar(title: "Organizations")

            if let errorMessage = viewModel.errorMessage {
                ManiNote(errorMessage, kind: .error)
                    .padding(.horizontal, ManiSpacing.lg)
                    .padding(.top, ManiSpacing.sm)
            }

            if let invitationError = invitations?.errorMessage {
                ManiNote(invitationError, kind: .error)
                    .padding(.horizontal, ManiSpacing.lg)
                    .padding(.top, ManiSpacing.sm)
            }

            if viewModel.isLoading && viewModel.organizations.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                // One list so every invitation and organization stays reachable by scrolling.
                List {
                    if let invitations {
                        Section("Invitations") {
                            if invitations.invites.isEmpty {
                                ScreenSubtitle(text: "No pending invitations")
                                    .listRowSeparator(.hidden)
                            }
                            ForEach(invitations.invites) { invite in
                                InvitationCard(invite: invite, viewModel: invitations)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    Section("Your organizations") {
                        if viewModel.organizations.isEmpty {
                            ManiNote("No organizations are assigned to this account.", kind: .warning)
                                .listRowSeparator(.hidden)
                        }
                        ForEach(viewModel.organizations) { org in
                            ManiListRow(
                                avatar: ManiAvatar(initials: initials(for: org.name)),
                                title: org.name,
                                status: org.orgId == viewModel.selectedOrgId ? ("Active", .success) : nil,
                                action: {
                                    Task { _ = await viewModel.select(org) }
                                }
                            )
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(theme.base.background.ignoresSafeArea())
        .task {
            await viewModel.load()
            await invitations?.refresh()
        }
        // Accepting an invite here adds an organization: re-read the list so it shows up without reopening.
        .onChange(of: invitations?.invites.count) { _, _ in
            Task { await viewModel.load() }
        }
        .modifier(InvitationSwitchPromptModifier(invitations: invitations))
    }

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        return String(trimmed.prefix(1)).uppercased()
    }
}
