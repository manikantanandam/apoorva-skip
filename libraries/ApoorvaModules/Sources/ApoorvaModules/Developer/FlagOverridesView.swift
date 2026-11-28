//
//  FlagOverridesView.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaFeatureFlags
import ManiSwiftUIComponents

public struct FlagOverridesView: View {
    @State var viewModel: FlagOverridesViewModel

    public init(viewModel: FlagOverridesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            Section {
                ForEach(viewModel.remoteConfigRows) { row in
                    RemoteConfigKeyRow(row: row, viewModel: viewModel)
                }
                Button("Fetch now") {
                    Task { await viewModel.fetchRemoteConfigNow() }
                }
                Button("Reset Remote Config overrides", role: .destructive) {
                    viewModel.resetRemoteConfigOverrides()
                }
            } header: {
                Text("Remote Config")
            } footer: {
                Text("Overrides existing flags only (local, never synced). Flags are added in code and the Firebase console.")
            }
        }
        .navigationTitle("Feature flags")
    }
}

/// One Remote Config key: its live remote value, an editable override, and an "Overridden" indicator.
/// The edit control itself varies by `row.kind` — see the per-kind subviews below.
struct RemoteConfigKeyRow: View {
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
            Text(row.isFromRemote ? "Remote: \(row.remoteDisplayValue)" : "Default: \(row.remoteDisplayValue) (not in Firebase)")
                .font(.caption)
                .foregroundStyle(.secondary)

            switch row.kind {
            case .bool:
                BoolOverrideControl(row: row, viewModel: viewModel)
            case .string, .number:
                TextOverrideControl(row: row, viewModel: viewModel)
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

struct BoolOverrideControl: View {
    let row: RemoteConfigRowDisplay
    let viewModel: FlagOverridesViewModel

    var body: some View {
        Toggle("Override", isOn: Binding(
            get: { row.effectiveDisplayValue == "On" },
            set: { viewModel.setRemoteConfigOverride(row.id, value: $0 ? "true" : "false") }
        ))
    }
}

struct TextOverrideControl: View {
    let row: RemoteConfigRowDisplay
    let viewModel: FlagOverridesViewModel
    @State var text: String = ""
    @State var invalidEntry = false

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

