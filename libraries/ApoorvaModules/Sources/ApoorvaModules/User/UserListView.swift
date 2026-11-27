//
//  UserListView.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

enum UserListRoute: Identifiable {
    case editRole(AppUser)

    var id: String {
        switch self {
        case .editRole(let user): return user.id
        }
    }
}

public struct UserListView: View {
    @Environment(\.maniTheme) var theme
    @Bindable var viewModel: UserListViewModel
    @State var activeRoute: UserListRoute?
    @State var inviteToRevoke: MemberInvite?
    private let onAddMember: (() -> Void)?

    public init(viewModel: UserListViewModel, onAddMember: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onAddMember = onAddMember
    }

    public var body: some View {
        VStack(spacing: 0) {
            ManiAppBar(title: "Team Members")

            ManiSearchField(text: $viewModel.searchText, placeholder: "Search by name or email")
                .padding(.horizontal, ManiSpacing.lg)
                .padding(.top, ManiSpacing.sm)

            if let onAddMember {
                ManiButton("Add member", icon: .plus, kind: .outline, action: onAddMember)
                    .padding(.horizontal, ManiSpacing.lg)
                    .padding(.top, ManiSpacing.sm)
            }

            if let errorMessage = viewModel.errorMessage {
                ManiNote(errorMessage, kind: .error)
                    .padding(.horizontal, ManiSpacing.lg)
                    .padding(.top, ManiSpacing.sm)
            }

            if viewModel.invitesLoadFailed {
                HStack {
                    ManiNote("Couldn't load pending invitations.", kind: .warning)
                    Button("Retry") { Task { await viewModel.loadInvites() } }
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, ManiSpacing.lg)
                .padding(.top, ManiSpacing.sm)
            }

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.filteredUsers.isEmpty && viewModel.filteredInvites.isEmpty {
                Spacer()
                ManiNote("No team members found. If this organization has existing members, their accounts may need to be re-synced before they appear here.", kind: .warning)
                    .padding(.horizontal, ManiSpacing.lg)
                Spacer()
            } else {
                List {
                    ForEach(viewModel.filteredUsers, id: \.id) { user in
                        ManiListRow(
                            avatar: ManiAvatar(initials: initials(for: user.name)),
                            title: user.name,
                            subtitle: user.email,
                            status: (viewModel.role(of: user).title, statusKind(for: viewModel.role(of: user))),
                            action: user.id == viewModel.currentUserId ? nil : {
                                activeRoute = .editRole(user)
                            }
                        )
                        .listRowSeparator(.hidden)
                    }
                    if !viewModel.filteredInvites.isEmpty {
                        Section("Pending invites") {
                            ForEach(viewModel.filteredInvites) { invite in
                                ManiListRow(
                                    avatar: ManiAvatar(initials: initials(for: invite.name)),
                                    title: invite.name,
                                    subtitle: invite.email,
                                    status: ("\(invite.role.title) · Pending", .warning),
                                    action: { inviteToRevoke = invite }
                                )
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(theme.base.background.ignoresSafeArea())
        .task { await viewModel.load() }
        .alert("Revoke invite?", isPresented: Binding(get: { inviteToRevoke != nil },
                                                      set: { if !$0 { inviteToRevoke = nil } })) {
            Button("Revoke", role: .destructive) {
                if let invite = inviteToRevoke { Task { await viewModel.revoke(invite) } }
                inviteToRevoke = nil
            }
            Button("Cancel", role: .cancel) { inviteToRevoke = nil }
        } message: {
            Text("\(inviteToRevoke?.email ?? "") won't be able to join this shop with this invite.")
        }
        .sheet(item: $activeRoute) { route in
            switch route {
            case .editRole(let user):
                UserRoleEditorView(user: user) { newRole in
                    Task {
                        await viewModel.updateRole(for: user, role: newRole)
                        activeRoute = nil
                    }
                }
            }
        }
    }

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        return String(trimmed.prefix(1)).uppercased()
    }

    private func statusKind(for role: OrgRole) -> ManiStatusKind {
        switch role {
        case .owner: return .success
        case .manager: return .warning
        case .cashier, .accountant: return .neutral
        }
    }
}
