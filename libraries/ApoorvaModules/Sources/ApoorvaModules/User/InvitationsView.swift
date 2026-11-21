//
//  InvitationsView.swift
//  ApoorvaModules
//
//  Pending invites to join a shop: the full screen (sheet), one card, and the Home banner.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

/// One invite with Accept / Decline. Shared by the sheet and the organization switcher.
struct InvitationCard: View {
    let invite: MemberInvite
    @Bindable var viewModel: InvitationsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.sm) {
            ManiListRow(avatar: ManiAvatar(initials: String(invite.orgName.prefix(1)).uppercased()),
                        title: invite.orgName,
                        subtitle: "\(invite.invitedByName) invited you as \(invite.role.title)",
                        status: nil, action: nil)
            HStack(spacing: ManiSpacing.sm) {
                ManiButton("Decline", kind: .outline, isEnabled: !viewModel.isWorking) {
                    Task { await viewModel.decline(invite) }
                }
                ManiButton("Accept", isLoading: viewModel.isWorking) {
                    Task { await viewModel.accept(invite) }
                }
            }
        }
    }
}

extension View {
    /// After accepting while already in another shop: offer to open the new one.
    func invitationSwitchPrompt(_ viewModel: InvitationsViewModel) -> some View {
        alert("Switch shop now?", isPresented: Binding(get: { viewModel.acceptedOrganization != nil },
                                                       set: { if !$0 { viewModel.acceptedOrganization = nil } })) {
            Button("Switch") {
                // Read the target now: the alert's dismissal clears `acceptedOrganization` before a Task would run.
                if let organization = viewModel.acceptedOrganization {
                    Task { await viewModel.switchTo(organization) }
                }
            }
            Button("Later", role: .cancel) { viewModel.acceptedOrganization = nil }
        } message: {
            Text("You joined \(viewModel.acceptedOrganization?.name ?? "the shop"). Switching changes the data shown in the app.")
        }
    }
}

struct InvitationSwitchPromptModifier: ViewModifier {
    let invitations: InvitationsViewModel?

    func body(content: Content) -> some View {
        if let invitations {
            content.invitationSwitchPrompt(invitations)
        } else {
            content
        }
    }
}

public struct InvitationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var viewModel: InvitationsViewModel

    public init(viewModel: InvitationsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScreenScroll {
            ManiAppBar(title: "Invitations")
            if viewModel.invites.isEmpty {
                ManiEmptyState(icon: .people, title: "No invitations", message: "When a shop owner invites your email, it shows up here.")
            }
            ForEach(viewModel.invites) { invite in
                InvitationCard(invite: invite, viewModel: viewModel)
            }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Done", kind: .outline) { dismiss() }
        }
        .task { await viewModel.refresh() }
        .invitationSwitchPrompt(viewModel)
    }
}

/// Home banner: shown only while invites are pending.
struct InvitationBanner: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        ManiNote(count == 1 ? "You have 1 shop invitation. Tap to review." : "You have \(count) shop invitations. Tap to review.",
                 kind: .info)
            .onTapGesture(perform: onTap)
    }
}
