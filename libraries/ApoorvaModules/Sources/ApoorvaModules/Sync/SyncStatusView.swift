//
//  SyncStatusView.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaRepository
import ManiSwiftUIComponents

/// Sync status (S15): overall state, per-collection last sync and errors, Sync now and Re-download all.
public struct SyncStatusView: View {
    @State var viewModel: SyncStatusViewModel
    @State var showsRedownloadConfirm = false

    public init(viewModel: SyncStatusViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        List {
            Section {
                ManiListRow(title: "Status", value: lastSyncText, status: overallBadge)
                if viewModel.totalPendingWrites > 0 {
                    ManiListRow(title: "Pending upload", value: "\(viewModel.totalPendingWrites) change\(viewModel.totalPendingWrites == 1 ? "" : "s")")
                }
                if viewModel.failedCount > 0 {
                    ManiNote("Some data couldn't be downloaded. Your entries are saved on this phone and upload when you're back online.",
                             kind: .warning)
                }
            }

            Section {
                ManiButton("Sync now", icon: .sync, isLoading: viewModel.isSyncing, isEnabled: !viewModel.isSyncing) {
                    Task { await viewModel.syncNow() }
                }
                Button("Re-download all data") { showsRedownloadConfirm = true }
                    .disabled(viewModel.isSyncing)
            } footer: {
                Text("Re-download fetches everything for this shop again. Use it if something looks missing.")
            }

            Section("Data") {
                ForEach(viewModel.sortedStatuses, id: \.key) { status in
                    ManiListRow(title: SyncStatusViewModel.title(for: status.key),
                                subtitle: subtitle(for: status),
                                status: badge(for: status))
                }
            }
        }
        .navigationTitle("Sync status")
        .refreshable { await viewModel.syncNow() }
        .task { await viewModel.load() }
        .confirmationDialog("Re-download all data?", isPresented: $showsRedownloadConfirm, titleVisibility: .visible) {
            Button("Re-download") { Task { await viewModel.redownloadAll() } }
        } message: {
            Text("This may take a while on a slow connection.")
        }
    }

    private var lastSyncText: String {
        viewModel.lastSuccessfulSync.map { "Last synced \(Self.format($0))" } ?? "Not synced yet"
    }

    private var overallBadge: (String, ManiStatusKind) {
        switch viewModel.overall {
        case .syncing: ("Syncing", .neutral)
        case .synced: ("Synced", .success)
        case .failed(let count): ("\(count) failed", .error)
        case .never: ("Waiting", .warning)
        }
    }

    private func subtitle(for status: SyncStatus) -> String {
        if let error = status.lastError { return error }
        return status.lastSuccess.map { "Synced \(Self.format($0))" } ?? "Not synced yet"
    }

    private func badge(for status: SyncStatus) -> (String, ManiStatusKind) {
        if status.isSyncing { return ("Syncing", .neutral) }
        if status.lastError != nil { return ("Failed", .error) }
        return status.lastSuccess == nil ? ("Pending", .warning) : ("OK", .success)
    }

    /// Time only for today, otherwise the day as well.
    private static func format(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? date.timeOnly : "\(date.shortDay), \(date.timeOnly)"
    }
}
