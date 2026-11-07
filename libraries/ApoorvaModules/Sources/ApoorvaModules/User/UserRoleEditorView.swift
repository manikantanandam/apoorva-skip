//
//  UserRoleEditorView.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

struct UserRoleEditorView: View {
    let user: AppUser
    let onSave: (AppUserRole) -> Void
    @State private var selectedRole: AppUserRole
    @Environment(\.dismiss) private var dismiss

    init(user: AppUser, onSave: @escaping (AppUserRole) -> Void) {
        self.user = user
        self.onSave = onSave
        self._selectedRole = State(initialValue: user.role)
    }

    var body: some View {
        VStack(spacing: ManiSpacing.lg) {
            ManiAppBar(title: user.name)

            ManiSegmentedControl(
                selection: $selectedRole,
                options: AppUserRole.allCases.map { (value: $0, title: $0.displayName) }
            )
            .padding(.horizontal, ManiSpacing.lg)

            Spacer()

            ManiButton("Save") {
                onSave(selectedRole)
                dismiss()
            }
            .padding(.horizontal, ManiSpacing.lg)
            .padding(.bottom, ManiSpacing.lg)
        }
        .padding(.top, ManiSpacing.md)
    }
}
