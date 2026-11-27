//
//  SyncStatusViewModelTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaRepository
@testable import ApoorvaModules

@MainActor
struct SyncStatusViewModelTests {
    private final class Recorder: @unchecked Sendable {
        var forced: [Bool] = []
        var statuses: [SyncStatus] = []
        var pendingWrites: [String: Int] = [:]
    }

    private func makeViewModel(_ recorder: Recorder) -> SyncStatusViewModel {
        SyncStatusViewModel(loadStatuses: { recorder.statuses },
                            loadPendingWrites: { recorder.pendingWrites },
                            runSync: { recorder.forced.append($0) })
    }

    @Test func overallIsNeverBeforeAnySync() async {
        let recorder = Recorder()
        recorder.statuses = [SyncStatus(key: "sales")]
        let viewModel = makeViewModel(recorder)
        await viewModel.load()
        #expect(viewModel.overall == .never)
        #expect(viewModel.lastSuccessfulSync == nil)
    }

    @Test func overallReportsFailuresAndSortsThemFirst() async {
        let recorder = Recorder()
        recorder.statuses = [SyncStatus(key: "sales", lastSuccess: Date()),
                             SyncStatus(key: "cashflow", lastError: "offline")]
        let viewModel = makeViewModel(recorder)
        await viewModel.load()
        #expect(viewModel.overall == .failed(1))
        #expect(viewModel.sortedStatuses.map(\.key) == ["cashflow", "sales"])
    }

    @Test func overallIsSyncedWhenAllSucceed() async {
        let recorder = Recorder()
        recorder.statuses = [SyncStatus(key: "sales", lastSuccess: Date())]
        let viewModel = makeViewModel(recorder)
        await viewModel.load()
        #expect(viewModel.overall == .synced)
    }

    @Test func syncNowAndRedownloadPassForceAndReloadStatuses() async {
        let recorder = Recorder()
        let viewModel = makeViewModel(recorder)
        recorder.statuses = [SyncStatus(key: "sales", lastSuccess: Date())]
        await viewModel.syncNow()
        await viewModel.redownloadAll()
        #expect(recorder.forced == [false, true])
        #expect(viewModel.statuses.count == 1)
        #expect(!viewModel.isSyncing)
    }

    @Test func totalPendingWritesSumsAcrossCollections() async {
        let recorder = Recorder()
        recorder.statuses = [SyncStatus(key: "sales", lastSuccess: Date())]
        recorder.pendingWrites = ["sales": 2, "cashflow": 3]
        let viewModel = makeViewModel(recorder)
        await viewModel.load()
        #expect(viewModel.totalPendingWrites == 5)
    }

    @Test func titlesCoverKnownAndOrgCollectionKeys() {
        #expect(SyncStatusViewModel.title(for: "dailyCashflowSummaries") == "Day balances")
        #expect(SyncStatusViewModel.title(for: "org.salaryPayments") == "Salary payments")
        #expect(SyncStatusViewModel.title(for: "org.stores") == "Stores")
    }
}
