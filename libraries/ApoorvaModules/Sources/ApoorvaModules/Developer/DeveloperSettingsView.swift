//
//  DeveloperSettingsView.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaUtilities

public struct DeveloperSettingsView: View {
    @State var viewModel: DeveloperSettingsViewModel
    @State private var showClearConfirm = false

    public init(viewModel: DeveloperSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            Section("Environment") {
                NavigationLink {
                    EnvironmentSwitchView(viewModel: viewModel)
                } label: {
                    HStack {
                        Text("Backend")
                        Spacer()
                        Text(viewModel.activeEnvironment.displayName)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Tools") {
                NavigationLink("Feature flags") {
                    FlagOverridesView(viewModel: viewModel)
                }
                NavigationLink("Logs") {
                    LogViewerView(viewModel: viewModel)
                }
                Toggle("Simulate offline", isOn: $viewModel.isOfflineSimulated)
                Toggle("Screen ID overlay", isOn: $viewModel.showsScreenIdentifiers)
            }

            if viewModel.canClearDatabase {
                Section("Data") {
                    Button("Clear local database", role: .destructive) {
                        showClearConfirm = true
                    }
                }
            }
        }
        .navigationTitle("Developer")
        .confirmationDialog("Clear local database?",
                            isPresented: $showClearConfirm,
                            titleVisibility: .visible) {
            Button("Clear", role: .destructive) { viewModel.clearLocalDatabase() }
        }
    }
}

/// "DEBUG" pill shown on every screen when not on production.
public struct EnvironmentBadgeView: View {
    let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        if let badge = environment.badge {
            Text(badge)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.orange)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
    }
}
