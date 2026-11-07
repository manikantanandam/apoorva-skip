//
//  LogViewerView.swift
//  ApoorvaModules
//

import SwiftUI

struct LogViewerView: View {
    @State var viewModel: DeveloperSettingsViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(viewModel.logLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption.monospaced())
                }
            }
            .padding()
        }
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: viewModel.logText)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Clear") { viewModel.clearLogs() }
            }
        }
    }
}
