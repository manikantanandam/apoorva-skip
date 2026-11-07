//
//  EnvironmentSwitchView.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaUtilities
import ManiSwiftUIComponents

struct EnvironmentSwitchView: View {
    @State var viewModel: DeveloperSettingsViewModel
    @State private var showConfirm = false

    var body: some View {
        List {
            Section {
                ForEach(AppEnvironment.allCases) { environment in
                    ManiListRow(
                        title: environment.displayName,
                        subtitle: environment.firebaseProjectId,
                        status: environment == viewModel.pendingEnvironment ? ("Selected", .success) : nil,
                        action: { viewModel.pendingEnvironment = environment }
                    )
                }
            } footer: {
                Text("Switching signs you out, clears local data for this device, and closes the app immediately. Reopen it to use the new environment.")
            }

            Section {
                Button("Switch and sign out") { showConfirm = true }
                    .disabled(!viewModel.canSwitchEnvironment)
            }
        }
        .navigationTitle("Environment")
        .confirmationDialog("Switch to \(viewModel.pendingEnvironment.displayName)?",
                            isPresented: $showConfirm,
                            titleVisibility: .visible) {
            Button("Switch and sign out", role: .destructive) {
                viewModel.confirmEnvironmentSwitch()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
