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
        }
        .navigationTitle("Feature flags")
    }
}
