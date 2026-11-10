//
//  FlagOverridesView.swift
//  ApoorvaModules
//

import SwiftUI
import ManiSwiftUIComponents

struct FlagOverridesView: View {
    @State var viewModel: DeveloperSettingsViewModel
    @State private var newFlag = ""

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
            Section("Remote Config") {
                ForEach(viewModel.remoteConfigRows) { row in
                    RemoteConfigKeyRow(row: row, viewModel: viewModel)
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

/// One Remote Config key: its live remote value, an editable override, and an "Overridden" indicator.
private struct RemoteConfigKeyRow: View {
    let row: RemoteConfigRowDisplay
    let viewModel: DeveloperSettingsViewModel
    @State private var text: String = ""
    @State private var invalidEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.title)
                if row.isOverridden {
                    Text("Overridden")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }
            Text("Remote: \(row.remoteDisplayValue)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if row.kind == .bool {
                Toggle("Override", isOn: Binding(
                    get: { row.effectiveDisplayValue == "On" },
                    set: { viewModel.setRemoteConfigOverride(row.id, value: $0 ? "true" : "false") }
                ))
            } else {
                HStack {
                    TextField("Override value", text: $text)
                        .autocorrectionDisabled()
                        .onAppear { text = row.overrideValue ?? row.remoteDisplayValue }
                    Button("Set") {
                        invalidEntry = !viewModel.setRemoteConfigOverride(for: row, rawValue: text)
                    }
                }
                if invalidEntry {
                    Text("Invalid value for this key's type")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .swipeActions {
            if row.isOverridden {
                Button("Clear override", role: .destructive) {
                    viewModel.setRemoteConfigOverride(row.id, value: nil)
                }
            }
        }
    }
}
