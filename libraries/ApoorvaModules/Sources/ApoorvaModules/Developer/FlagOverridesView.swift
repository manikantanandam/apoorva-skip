//
//  FlagOverridesView.swift
//  ApoorvaModules
//

import SwiftUI
import ManiSwiftUIComponents

struct FlagOverridesView: View {
    @State var viewModel: DeveloperSettingsViewModel
    @State private var newFlag = ""
    @State private var newRemoteConfigKey = ""
    @State private var newRemoteConfigValue = ""

    var body: some View {
        List {
            Section("Local overrides (never synced)") {
                ForEach(viewModel.flagOverrides.keys.sorted(), id: \.self) { key in
                    ManiToggleRow(title: key, isOn: Binding(
                        get: { viewModel.flagOverrides[key] ?? false },
                        set: { viewModel.setFlag(key, value: $0) }
                    ))
                    .swipeActions {
                        Button("Remove", role: .destructive) {
                            viewModel.setFlag(key, value: nil)
                        }
                    }
                }
                HStack {
                    TextField("Flag key", text: $newFlag)
                        .autocorrectionDisabled()
                    Button("Add") {
                        viewModel.addFlag(newFlag)
                        newFlag = ""
                    }
                }
            }
            Section {
                Button("Reset all overrides", role: .destructive) {
                    viewModel.resetFlags()
                }
            }
            Section("Remote Config overrides (local only, never synced)") {
                ForEach(viewModel.remoteConfigOverrides.keys.sorted(), id: \.self) { key in
                    HStack {
                        Text(key)
                        Spacer()
                        Text(viewModel.remoteConfigOverrides[key] ?? "")
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) {
                            viewModel.setRemoteConfigOverride(key, value: nil)
                        }
                    }
                }
                HStack {
                    TextField("Key", text: $newRemoteConfigKey)
                        .autocorrectionDisabled()
                    TextField("Value", text: $newRemoteConfigValue)
                        .autocorrectionDisabled()
                    Button("Add") {
                        viewModel.addRemoteConfigOverride(newRemoteConfigKey, value: newRemoteConfigValue)
                        newRemoteConfigKey = ""
                        newRemoteConfigValue = ""
                    }
                }
                Button("Fetch now") {
                    Task { await viewModel.fetchRemoteConfigNow() }
                }
                Button("Reset Remote Config overrides", role: .destructive) {
                    viewModel.resetRemoteConfigOverrides()
                }
            }
        }
        .navigationTitle("Feature flags")
    }
}
