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
import ManiLogger

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

@MainActor @Observable
public class DeveloperSettingsViewModel {
    private let authService: AuthServicing
    private let environmentStore: EnvironmentStore
    private var tools: DeveloperToolsProtocol
    private let remoteConfigService: RemoteConfigServicing
    private let clearLocalDatabaseAction: () -> Void
    private let terminateAppAction: () -> Void

    /// Backs the Logs screen (`ManiLogger.LogViewerView`).
    public let logViewer: LogViewerViewModel

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
                terminateApp: @escaping () -> Void) {
        self.authService = authService
        self.environmentStore = environmentStore
        self.tools = tools
        self.remoteConfigService = remoteConfigService
        self.logViewer = LogViewerViewModel(logBuffer: logBuffer, fileLogSink: fileLogSink)
        self.clearLocalDatabaseAction = clearLocalDatabase
        self.terminateAppAction = terminateApp
        self.activeEnvironment = environmentStore.current
        self.pendingEnvironment = environmentStore.current
        self.flagOverrides = tools.flagOverrides
        self.remoteConfigOverrides = tools.remoteConfigOverrides
        self.isOfflineSimulated = tools.isOfflineSimulated
        self.showsScreenIdentifiers = tools.showsScreenIdentifiers
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


    public func clearLocalDatabase() {
        guard canClearDatabase else { return }
        clearLocalDatabaseAction()
    }
}
