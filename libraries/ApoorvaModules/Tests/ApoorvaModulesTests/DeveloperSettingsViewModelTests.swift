//
//  DeveloperSettingsViewModelTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaServices
import ApoorvaEnvironment
import ApoorvaLogging
@testable import ApoorvaModules

@MainActor
struct DeveloperSettingsViewModelTests {
    private func makeViewModel(remoteConfig: RemoteConfigServicing = NoOpRemoteConfigService(),
                                tools: StubDeveloperTools = StubDeveloperTools(),
                                logBuffer: LogBuffer = LogBuffer(),
                                now: Date = Date())
    -> DeveloperSettingsViewModel {
        DeveloperSettingsViewModel(
            authService: MockAuthService(),
            environmentStore: EnvironmentStore(defaults: UserDefaults(suiteName: "DevSettingsTests-\(UUID().uuidString)")!),
            tools: tools,
            remoteConfigService: remoteConfig,
            logBuffer: logBuffer,
            clearLocalDatabase: {},
            terminateApp: {},
            now: { now }
        )
    }

    private func entry(_ message: String, level: LogLevel = .info, category: LogCategory = .app,
                       date: Date = Date()) -> LogEntry {
        LogEntry(date: date, level: level, category: category, message: message, sessionId: "s")
    }

    @Test func categoryFilterEmptyMeansAllAndSupportsMultipleSelection() {
        let buffer = LogBuffer()
        buffer.write(entry("a", category: .sync))
        buffer.write(entry("b", category: .auth))
        buffer.write(entry("c", category: .ui))
        let viewModel = makeViewModel(logBuffer: buffer)

        #expect(viewModel.filteredLogEntries.count == 3)
        viewModel.toggleLogCategory(.sync)
        #expect(viewModel.filteredLogEntries.map(\.message) == ["a"])
        viewModel.toggleLogCategory(.auth)
        #expect(viewModel.filteredLogEntries.map(\.message) == ["b", "a"])
        viewModel.toggleLogCategory(.sync)
        #expect(viewModel.filteredLogEntries.map(\.message) == ["b"])
        viewModel.clearLogCategories()
        #expect(viewModel.filteredLogEntries.count == 3)
    }

    @Test func timeRangeKeepsOnlyRecentEntries() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let buffer = LogBuffer()
        buffer.write(entry("2h", date: now.addingTimeInterval(-7_200)))
        buffer.write(entry("10m", date: now.addingTimeInterval(-600)))
        buffer.write(entry("2m", date: now.addingTimeInterval(-120)))
        let viewModel = makeViewModel(logBuffer: buffer, now: now)

        viewModel.logTimeRange = .last5m
        #expect(viewModel.filteredLogEntries.map(\.message) == ["2m"])
        viewModel.logTimeRange = .last15m
        #expect(viewModel.filteredLogEntries.map(\.message) == ["2m", "10m"])
        viewModel.logTimeRange = .all
        #expect(viewModel.filteredLogEntries.count == 3)
    }

    @Test func categoryCountsIgnoreCategorySelectionButRespectOtherFilters() {
        let buffer = LogBuffer()
        buffer.write(entry("pull ok", category: .sync))
        buffer.write(entry("pull failed", level: .error, category: .sync))
        buffer.write(entry("login failed", level: .error, category: .auth))
        let viewModel = makeViewModel(logBuffer: buffer)

        viewModel.toggleLogCategory(.auth)
        #expect(viewModel.logCategoryCounts == [.sync: 2, .auth: 1])
        viewModel.logLevelFilter = .error
        viewModel.logSearchText = "pull"
        #expect(viewModel.logCategoryCounts == [.sync: 1])
        #expect(viewModel.filteredLogEntries.isEmpty)
    }

    @Test func resultSummaryAndResetFilters() {
        let buffer = LogBuffer()
        buffer.write(entry("x", category: .sync))
        buffer.write(entry("y", category: .ui))
        let viewModel = makeViewModel(logBuffer: buffer)

        #expect(viewModel.hasActiveLogFilters == false)
        viewModel.toggleLogCategory(.sync)
        viewModel.logTimeRange = .last1h
        #expect(viewModel.logResultSummary == "1 of 2")
        #expect(viewModel.hasActiveLogFilters)

        viewModel.resetLogFilters()
        #expect(viewModel.logResultSummary == "2 of 2")
        #expect(viewModel.hasActiveLogFilters == false)
    }

    @Test func logFilterAppliesLevelAndSearchNewestFirst() {
        let buffer = LogBuffer()
        buffer.write(LogEntry(level: .debug, category: .sync, message: "pull started", sessionId: "s"))
        buffer.write(LogEntry(level: .error, category: .sync, message: "pull failed", sessionId: "s"))
        buffer.write(LogEntry(level: .error, category: .auth, message: "token expired", sessionId: "s"))
        let viewModel = makeViewModel(logBuffer: buffer)

        viewModel.logLevelFilter = .warning
        #expect(viewModel.filteredLogEntries.map(\.message) == ["token expired", "pull failed"])

        viewModel.logSearchText = "sync"
        #expect(viewModel.filteredLogEntries.map(\.message) == ["pull failed"])
    }

    @Test func clearLogsEmptiesBufferAndEntries() {
        let buffer = LogBuffer()
        buffer.write(LogEntry(level: .info, category: .app, message: "x", sessionId: "s"))
        let viewModel = makeViewModel(logBuffer: buffer)

        viewModel.clearLogs()
        #expect(viewModel.logEntries.isEmpty)
        #expect(buffer.entries.isEmpty)
    }

    @Test func rowShowsRemoteValueWhenNotOverridden() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults([FeatureFlag.holdBills.rawValue: .bool(true)])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)

        let row = viewModel.remoteConfigRows.first { $0.id == FeatureFlag.holdBills.rawValue }
        #expect(row?.remoteDisplayValue == "On")
        #expect(row?.isOverridden == false)
        #expect(row?.effectiveDisplayValue == "On")
    }

    @Test func rowShowsOverrideAndIsMarkedOverridden() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults([FeatureFlag.holdBills.rawValue: .bool(true)])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)

        viewModel.setRemoteConfigOverride(FeatureFlag.holdBills.rawValue, value: "false")
        let row = viewModel.remoteConfigRows.first { $0.id == FeatureFlag.holdBills.rawValue }
        #expect(row?.remoteDisplayValue == "On")
        #expect(row?.isOverridden == true)
        #expect(row?.effectiveDisplayValue == "Off")
    }

    @Test func resetRevertsToRemoteValue() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults([FeatureFlag.holdBills.rawValue: .bool(true)])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)

        viewModel.setRemoteConfigOverride(FeatureFlag.holdBills.rawValue, value: "false")
        viewModel.resetRemoteConfigOverrides()
        let row = viewModel.remoteConfigRows.first { $0.id == FeatureFlag.holdBills.rawValue }
        #expect(row?.isOverridden == false)
        #expect(row?.effectiveDisplayValue == "On")
    }

    @Test func nonBoolKeyRejectsInvalidOverride() {
        let viewModel = makeViewModel()
        guard let row = viewModel.remoteConfigRows.first(where: { $0.id == "min_app_version" }) else {
            Issue.record("expected min_app_version in the catalogue")
            return
        }
        #expect(viewModel.setRemoteConfigOverride(for: row, rawValue: "2.0.0"))
        #expect(viewModel.remoteConfigRows.first { $0.id == "min_app_version" }?.overrideValue == "2.0.0")
    }

    @Test func versionGateOverrideRoundTrips() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults(["test.gate": .json(try! JSONEncoder().encode(VersionGateValue(enabled: false)))])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)

        #expect(viewModel.versionGateRemoteValue(forKey: "test.gate") == VersionGateValue(enabled: false))
        #expect(viewModel.versionGateOverrideValue(forKey: "test.gate") == nil)

        viewModel.setVersionGateOverride(key: "test.gate", value: VersionGateValue(enabled: true, minVersion: "2.3.0"))
        #expect(viewModel.versionGateOverrideValue(forKey: "test.gate") == VersionGateValue(enabled: true, minVersion: "2.3.0"))
    }
}
