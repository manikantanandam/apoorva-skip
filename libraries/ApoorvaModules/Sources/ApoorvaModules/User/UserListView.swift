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
    @Environment(\.maniTheme) private var theme
    @Bindable var viewModel: UserListViewModel
    @State private var activeRoute: UserListRoute?

    public init(viewModel: UserListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            ManiAppBar(title: "Team Members")

            ManiSearchField(text: $viewModel.searchText, placeholder: "Search by name or email")
                .padding(.horizontal, ManiSpacing.lg)
                .padding(.top, ManiSpacing.sm)

            if let errorMessage = viewModel.errorMessage {
                ManiNote(errorMessage, kind: .error)
                    .padding(.horizontal, ManiSpacing.lg)
                    .padding(.top, ManiSpacing.sm)
            }

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.filteredUsers.isEmpty {
                Spacer()
                ManiNote("No team members found. If this organization has existing members, their accounts may need to be re-synced before they appear here.", kind: .warning)
                    .padding(.horizontal, ManiSpacing.lg)
                Spacer()
            } else {
                List(viewModel.filteredUsers, id: \.id) { user in
                    ManiListRow(
                        avatar: ManiAvatar(initials: initials(for: user.name)),
                        title: user.name,
                        subtitle: user.email,
                        status: (user.role.displayName, statusKind(for: user.role)),
                        action: user.id == viewModel.currentUserId ? nil : {
                            activeRoute = .editRole(user)
                        }
                    )
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .background(theme.base.background.ignoresSafeArea())
        .task { await viewModel.load() }
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

    private func statusKind(for role: AppUserRole) -> ManiStatusKind {
        switch role {
        case .superAdmin, .admin: return .success
        case .manager: return .warning
        case .standard: return .neutral
        }
    }
}
