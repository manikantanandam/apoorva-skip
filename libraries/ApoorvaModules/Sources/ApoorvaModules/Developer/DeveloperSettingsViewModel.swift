//
//  DeveloperSettingsViewModel.swift
//  ApoorvaModules
//

import Foundation
import Observation
import ApoorvaModels
import ApoorvaServices
import ApoorvaUtilities
import ApoorvaEnvironment
import ApoorvaLogging

private let logger = AppLogger(category: .app)

/// One row of the catalogue-driven Remote Config list in Developer Settings: the live remote
/// value, plus the local override if one is set.
public struct RemoteConfigRowDisplay: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let kind: RemoteConfigValueKind
    public let remoteDisplayValue: String
    public let overrideValue: String?
    public var isOverridden: Bool { overrideValue != nil }
    public var effectiveDisplayValue: String { overrideValue ?? remoteDisplayValue }
}

/// How far back the log viewer looks.
public enum LogTimeRange: CaseIterable, Sendable {
    case last5m, last15m, last1h, all

    public var title: String {
        switch self {
        case .last5m: return "5 min"
        case .last15m: return "15 min"
        case .last1h: return "1 hour"
        case .all: return "All"
        }
    }

    public var interval: TimeInterval? {
        switch self {
        case .last5m: return 5 * 60
        case .last15m: return 15 * 60
        case .last1h: return 60 * 60
        case .all: return nil
        }
    }
}

@MainActor @Observable
public class DeveloperSettingsViewModel {
    private let authService: AuthServicing
    private let environmentStore: EnvironmentStore
    private var tools: DeveloperToolsProtocol
    private let remoteConfigService: RemoteConfigServicing
    private let logBuffer: LogBuffer
    private let fileLogSink: FileLogSink?
    private let clearLocalDatabaseAction: () -> Void
    private let terminateAppAction: () -> Void
    private let now: () -> Date

    /// Environment the app was launched with; switching only takes effect after relaunch.
    public let activeEnvironment: AppEnvironment
    public var pendingEnvironment: AppEnvironment
    public var errorMessage: String?

    public var flagOverrides: [String: Bool]
    public var remoteConfigOverrides: [String: String]
    public var isOfflineSimulated: Bool {
        didSet { tools.isOfflineSimulated = isOfflineSimulated }
    }
    public var showsScreenIdentifiers: Bool {
        didSet { tools.showsScreenIdentifiers = showsScreenIdentifiers }
    }

    public init(authService: AuthServicing,
                environmentStore: EnvironmentStore,
                tools: DeveloperToolsProtocol,
                remoteConfigService: RemoteConfigServicing,
                logBuffer: LogBuffer,
                fileLogSink: FileLogSink? = nil,
                clearLocalDatabase: @escaping () -> Void,
                terminateApp: @escaping () -> Void,
                now: @escaping () -> Date = Date.init) {
        self.authService = authService
        self.now = now
        self.environmentStore = environmentStore
        self.tools = tools
        self.remoteConfigService = remoteConfigService
        self.logBuffer = logBuffer
        self.fileLogSink = fileLogSink
        self.clearLocalDatabaseAction = clearLocalDatabase
        self.terminateAppAction = terminateApp
        self.activeEnvironment = environmentStore.current
        self.pendingEnvironment = environmentStore.current
        self.flagOverrides = tools.flagOverrides
        self.remoteConfigOverrides = tools.remoteConfigOverrides
        self.isOfflineSimulated = tools.isOfflineSimulated
        self.showsScreenIdentifiers = tools.showsScreenIdentifiers
        self.logEntries = logBuffer.entries
    }

    /// Everything in the in-memory buffer, oldest first.
    public private(set) var logEntries: [LogEntry]
    /// Minimum level shown in the log viewer.
    public var logLevelFilter: LogLevel = .debug
    public var logSearchText = ""
    /// Categories shown in the log viewer; empty means all.
    public private(set) var selectedLogCategories: Set<LogCategory> = []
    public var logTimeRange: LogTimeRange = .all

    public var logSearchQuery: String { logSearchText.trimmingCharacters(in: .whitespaces) }

    public var hasActiveLogFilters: Bool {
        logLevelFilter != .debug || !selectedLogCategories.isEmpty || logTimeRange != .all || !logSearchQuery.isEmpty
    }

    /// Entries after level, category, time and search filtering, newest first.
    public var filteredLogEntries: [LogEntry] {
        entriesMatchingNonCategoryFilters.filter { selectedLogCategories.isEmpty || selectedLogCategories.contains($0.category) }
    }

    /// Per-category counts under the level/time/search filters (ignoring the category selection),
    /// so each chip shows what selecting it would reveal.
    public var logCategoryCounts: [LogCategory: Int] {
        Dictionary(grouping: entriesMatchingNonCategoryFilters, by: \.category).mapValues(\.count)
    }

    /// "12 of 340"
    public var logResultSummary: String {
        "\(filteredLogEntries.count) of \(logEntries.count)"
    }

    public func toggleLogCategory(_ category: LogCategory) {
        if selectedLogCategories.contains(category) {
            selectedLogCategories.remove(category)
        } else {
            selectedLogCategories.insert(category)
        }
    }

    public func clearLogCategories() {
        selectedLogCategories = []
    }

    public func resetLogFilters() {
        logLevelFilter = .debug
        selectedLogCategories = []
        logTimeRange = .all
        logSearchText = ""
    }

    private var entriesMatchingNonCategoryFilters: [LogEntry] {
        let query = logSearchQuery
        let cutoff = logTimeRange.interval.map { now().addingTimeInterval(-$0) }
        return logEntries.reversed().filter { entry in
            entry.level >= logLevelFilter
                && (cutoff.map { entry.date >= $0 } ?? true)
                && (query.isEmpty
                    || entry.message.localizedCaseInsensitiveContains(query)
                    || entry.category.rawValue.localizedCaseInsensitiveContains(query))
        }
    }

    /// Full on-disk log (both rotated files) when available, else the in-memory buffer.
    public var logText: String {
        let fileText = fileLogSink?.contents() ?? ""
        return fileText.isEmpty ? logBuffer.shareableText : fileText
    }

    public func reloadLogs() {
        logEntries = logBuffer.entries
    }
    public var canClearDatabase: Bool { activeEnvironment.allowsDestructiveTools }
    public var canSwitchEnvironment: Bool { pendingEnvironment != activeEnvironment }

    /// Signs out, wipes local state for a clean switch, persists the new environment, then kills the app.
    public func confirmEnvironmentSwitch() {
        logger.info("confirmEnvironmentSwitch: active=\(activeEnvironment) pending=\(pendingEnvironment) canSwitch=\(canSwitchEnvironment)")
        guard canSwitchEnvironment else { return }
        do {
            try authService.logout()
            if activeEnvironment.allowsDestructiveTools {
                clearLocalDatabaseAction()
            }
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }
            environmentStore.current = pendingEnvironment
            terminateAppAction()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func setFlag(_ key: String, value: Bool?) {
        tools.setFlagOverride(key, value: value)
        flagOverrides = tools.flagOverrides
    }

    public func addFlag(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        setFlag(trimmed, value: true)
    }

    public func resetFlags() {
        tools.clearFlagOverrides()
        flagOverrides = [:]
    }

    /// The locally declared Remote Config keys with their live remote value and, if set, override.
    public var remoteConfigRows: [RemoteConfigRowDisplay] {
        RemoteConfigCatalog.all.map { definition in
            let remoteDisplay = Self.displayValue(forRemote: definition, service: remoteConfigService)
            let overrideDisplay = remoteConfigOverrides[definition.key].map { raw in
                Self.displayValue(forOverrideRaw: raw, kind: definition.kind)
            }
            return RemoteConfigRowDisplay(id: definition.key, title: definition.title, kind: definition.kind,
                                           remoteDisplayValue: remoteDisplay, overrideValue: overrideDisplay)
        }
    }

    private static func displayValue(forRemote definition: RemoteConfigKeyDefinition, service: RemoteConfigServicing) -> String {
        switch definition.kind {
        case .bool: return service.boolValue(forKey: definition.key) ? "On" : "Off"
        case .string: return service.stringValue(forKey: definition.key) ?? definition.defaultString
        case .number: return formatted(service.numberValue(forKey: definition.key) ?? definition.defaultNumber)
        case .versionGate: return formatted(service.jsonValue(forKey: definition.key, as: VersionGateValue.self) ?? definition.defaultVersionGate)
        }
    }

    private static func displayValue(forOverrideRaw raw: String, kind: RemoteConfigValueKind) -> String {
        switch kind {
        case .bool: return (Bool(raw) ?? false) ? "On" : "Off"
        case .string, .number: return raw
        case .versionGate:
            guard let data = raw.data(using: .utf8), let gate = try? JSONDecoder().decode(VersionGateValue.self, from: data) else { return raw }
            return formatted(gate)
        }
    }

    private static func formatted(_ number: Double) -> String {
        number == number.rounded() ? String(Int(number)) : String(number)
    }

    private static func formatted(_ gate: VersionGateValue) -> String {
        guard gate.enabled else { return "Off" }
        guard let minVersion = gate.minVersion else { return "On" }
        return "On ≥ \(minVersion)"
    }

    public func setRemoteConfigOverride(_ key: String, value: String?) {
        tools.setRemoteConfigOverride(key, value: value)
        remoteConfigOverrides = tools.remoteConfigOverrides
    }

    /// Validates `rawValue` against `row.kind` before storing it as the override.
    /// Returns `false` (and makes no change) when the text doesn't parse for that kind.
    @discardableResult
    public func setRemoteConfigOverride(for row: RemoteConfigRowDisplay, rawValue: String) -> Bool {
        switch row.kind {
        case .bool:
            guard let bool = Bool(rawValue) else { return false }
            setRemoteConfigOverride(row.id, value: bool ? "true" : "false")
        case .string:
            setRemoteConfigOverride(row.id, value: rawValue)
        case .number:
            guard Double(rawValue) != nil else { return false }
            setRemoteConfigOverride(row.id, value: rawValue)
        case .versionGate:
            // Edited via `setVersionGateOverride`, not this raw-text path.
            return false
        }
        return true
    }

    public func versionGateRemoteValue(forKey key: String) -> VersionGateValue {
        let defaultValue = RemoteConfigCatalog.all.first { $0.key == key }?.defaultVersionGate ?? VersionGateValue(enabled: false)
        return remoteConfigService.jsonValue(forKey: key, as: VersionGateValue.self) ?? defaultValue
    }

    public func versionGateOverrideValue(forKey key: String) -> VersionGateValue? {
        guard let raw = remoteConfigOverrides[key], let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(VersionGateValue.self, from: data)
    }

    public func setVersionGateOverride(key: String, value: VersionGateValue) {
        guard let data = try? JSONEncoder().encode(value), let json = String(data: data, encoding: .utf8) else { return }
        setRemoteConfigOverride(key, value: json)
    }

    public func resetRemoteConfigOverrides() {
        tools.clearRemoteConfigOverrides()
        remoteConfigOverrides = [:]
    }

    public func fetchRemoteConfigNow() async {
        do {
            try await remoteConfigService.fetchAndActivate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clearLogs() {
        logBuffer.clear()
        fileLogSink?.clear()
        reloadLogs()
    }

    public func clearLocalDatabase() {
        guard canClearDatabase else { return }
        clearLocalDatabaseAction()
    }
}
