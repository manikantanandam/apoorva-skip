//
//  OrganizationListView.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct OrganizationListView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable var viewModel: OrganizationListViewModel

    public init(viewModel: OrganizationListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            ManiAppBar(title: "Organizations")

            if let errorMessage = viewModel.errorMessage {
                ManiNote(errorMessage, kind: .error)
                    .padding(.horizontal, ManiSpacing.lg)
                    .padding(.top, ManiSpacing.sm)
            }

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.organizations.isEmpty {
                Spacer()
                ManiNote("No organizations are assigned to this account.", kind: .warning)
                    .padding(.horizontal, ManiSpacing.lg)
                Spacer()
            } else {
                List(viewModel.organizations) { org in
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
                .listStyle(.plain)
            }
        }
        .background(theme.base.background.ignoresSafeArea())
        .task { await viewModel.load() }
    }

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        return String(trimmed.prefix(1)).uppercased()
    }
}
