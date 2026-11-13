//
//  DeveloperSettingsView.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaUtilities
import ApoorvaEnvironment
import ManiSwiftUIComponents

public struct DeveloperSettingsView: View {
    @State var viewModel: DeveloperSettingsViewModel
    @State private var showClearConfirm = false

    private let onOpenEnvironment: () -> Void
    private let onOpenFlags: () -> Void
    private let onOpenLogs: () -> Void

    public init(viewModel: DeveloperSettingsViewModel,
                onOpenEnvironment: @escaping () -> Void,
                onOpenFlags: @escaping () -> Void,
                onOpenLogs: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onOpenEnvironment = onOpenEnvironment
        self.onOpenFlags = onOpenFlags
        self.onOpenLogs = onOpenLogs
    }

    public var body: some View {
        List {
            Section("Environment") {
                Button(action: onOpenEnvironment) {
                    ManiListRow(title: "Backend", value: viewModel.activeEnvironment.displayName)
                }
                .buttonStyle(.plain)
            }

            Section("Tools") {
                Button("Feature flags", action: onOpenFlags)
                Button("Logs", action: onOpenLogs)
                ManiToggleRow(title: "Simulate offline", isOn: $viewModel.isOfflineSimulated)
                ManiToggleRow(title: "Screen ID overlay", isOn: $viewModel.showsScreenIdentifiers)
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
            ManiStatusBadge(badge, kind: .warning)
        }
    }
}
