//
//  FlagOverridesView.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct FlagOverridesView: View {
    @State var viewModel: FlagOverridesViewModel
    @State private var newFlag = ""

    public init(viewModel: FlagOverridesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
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
/// The edit control itself varies by `row.kind` — see the per-kind subviews below.
private struct RemoteConfigKeyRow: View {
    let row: RemoteConfigRowDisplay
    let viewModel: FlagOverridesViewModel

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

            switch row.kind {
            case .bool:
                BoolOverrideControl(row: row, viewModel: viewModel)
            case .string, .number:
                TextOverrideControl(row: row, viewModel: viewModel)
            case .versionGate:
                VersionGateOverrideControl(row: row, viewModel: viewModel)
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

private struct BoolOverrideControl: View {
    let row: RemoteConfigRowDisplay
    let viewModel: FlagOverridesViewModel

    var body: some View {
        Toggle("Override", isOn: Binding(
            get: { row.effectiveDisplayValue == "On" },
            set: { viewModel.setRemoteConfigOverride(row.id, value: $0 ? "true" : "false") }
        ))
    }
}

private struct TextOverrideControl: View {
    let row: RemoteConfigRowDisplay
    let viewModel: FlagOverridesViewModel
    @State private var text: String = ""
    @State private var invalidEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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
}

private struct VersionGateOverrideControl: View {
    let row: RemoteConfigRowDisplay
    let viewModel: FlagOverridesViewModel
    @State private var enabled = false
    @State private var minVersion = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle("Enabled", isOn: $enabled)
            HStack {
                TextField("Min version (optional)", text: $minVersion)
                    .autocorrectionDisabled()
                Button("Set") {
                    viewModel.setVersionGateOverride(
                        key: row.id,
                        value: VersionGateValue(enabled: enabled, minVersion: minVersion.isEmpty ? nil : minVersion)
                    )
                }
            }
        }
        .onAppear {
            let current = viewModel.versionGateOverrideValue(forKey: row.id) ?? viewModel.versionGateRemoteValue(forKey: row.id)
            enabled = current.enabled
            minVersion = current.minVersion ?? ""
        }
    }
}
