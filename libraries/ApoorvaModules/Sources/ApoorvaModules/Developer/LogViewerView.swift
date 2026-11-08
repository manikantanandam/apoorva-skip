//
//  LogViewerView.swift
//  ApoorvaModules
//

import SwiftUI
import ManiSwiftUIComponents

struct LogViewerView: View {
    @Environment(\.maniTheme) private var theme
    @State var viewModel: DeveloperSettingsViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ManiSpacing.xs) {
                ForEach(Array(viewModel.logLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.base.text)
                }
            }
            .padding(ManiSpacing.lg)
        }
        .background(theme.base.background.ignoresSafeArea())
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
