//
//  LogViewerView.swift
//  ApoorvaModules
//

import SwiftUI
import ManiSwiftUIComponents
import ApoorvaLogging

struct LogViewerView: View {
    @Environment(\.maniTheme) private var theme
    @State var viewModel: DeveloperSettingsViewModel

    var body: some View {
        List {
            Section {
                Picker("Minimum level", selection: $viewModel.logLevelFilter) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                FlowLayout {
                    ForEach(LogTimeRange.allCases, id: \.self) { range in
                        ManiChip(range.title, isSelected: viewModel.logTimeRange == range) { viewModel.logTimeRange = range }
                    }
                }
                FlowLayout {
                    ManiChip("All", isSelected: viewModel.selectedLogCategories.isEmpty) { viewModel.clearLogCategories() }
                    ForEach(visibleCategories, id: \.self) { category in
                        ManiChip("\(category.rawValue) (\(viewModel.logCategoryCounts[category] ?? 0))",
                                 isSelected: viewModel.selectedLogCategories.contains(category)) {
                            viewModel.toggleLogCategory(category)
                        }
                    }
                }
            } header: {
                HStack {
                    Text(viewModel.logResultSummary)
                    Spacer()
                    if viewModel.hasActiveLogFilters {
                        Button("Reset filters") { viewModel.resetLogFilters() }
                            .font(.caption)
                    }
                }
            }
            Section {
                if viewModel.filteredLogEntries.isEmpty {
                    Text("No logs")
                        .foregroundStyle(theme.base.textSecondary)
                }
                ForEach(Array(viewModel.filteredLogEntries.enumerated()), id: \.offset) { _, entry in
                    NavigationLink {
                        LogDetailView(entry: entry, searchQuery: viewModel.logSearchQuery)
                    } label: {
                        VStack(alignment: .leading, spacing: ManiSpacing.xs) {
                            Text("\(entry.date.formatted(date: .omitted, time: .standard))  \(entry.level.label)  [\(entry.category.rawValue)]")
                                .font(.caption2.monospaced())
                                .foregroundStyle(LogEntryStyle.color(for: entry.level))
                            // Capped so long entries (e.g. config dumps) don't blow up row height; full text in detail.
                            Text(LogEntryStyle.highlighted(entry.message, query: viewModel.logSearchQuery, accent: theme.accent.accent))
                                .font(.caption.monospaced())
                                .foregroundStyle(theme.base.text)
                                .lineLimit(5)
                                .truncationMode(.tail)
                        }
                    }
                }
            }
        }
        .searchable(text: $viewModel.logSearchText, prompt: "Search messages or categories")
        .refreshable { viewModel.reloadLogs() }
        .onAppear { viewModel.reloadLogs() }
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

    /// Categories with matching entries, plus any selected ones so they can be deselected.
    private var visibleCategories: [LogCategory] {
        LogCategory.allCases.filter {
            (viewModel.logCategoryCounts[$0] ?? 0) > 0 || viewModel.selectedLogCategories.contains($0)
        }
    }
}
