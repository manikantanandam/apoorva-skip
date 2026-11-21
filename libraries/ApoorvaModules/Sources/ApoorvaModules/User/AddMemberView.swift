//
//  AddMemberView.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct AddMemberView: View {
    @Bindable private var viewModel: AddMemberViewModel
    private let onDone: () -> Void

    public init(viewModel: AddMemberViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    public var body: some View {
        ScreenScroll {
            ManiInputField(label: "Email", text: $viewModel.email, placeholder: "staff@example.com", keyboard: .email)
            ManiInputField(label: "Name", text: $viewModel.name)
            SectionHeader(title: "Role")
            Picker("Role", selection: $viewModel.role) {
                ForEach(MemberInvite.invitableRoles, id: \.self) { role in
                    Text(role.title).tag(role)
                }
            }
            .pickerStyle(.segmented)
            if viewModel.stores.count > 1 {
                SectionHeader(title: "Store access")
                ForEach(viewModel.stores) { store in
                    Toggle(store.name, isOn: Binding(
                        get: { viewModel.selectedStoreIds.contains(store.id) },
                        set: { _ in viewModel.toggleStore(store.id) }))
                }
            }
            ManiNote("They'll see this invite after signing in to Apoorva with this email. Ask them to install the app.", kind: .info)
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Send invite", isLoading: viewModel.isSaving, isEnabled: viewModel.canSend) {
                Task { if await viewModel.send() { onDone() } }
            }
        }
        .navigationTitle("Add member")
    }
}
