//
//  DeveloperSettingsViewModel.swift
//  ApoorvaModules
//

import Foundation
import Observation
import ApoorvaServices
import ApoorvaUtilities
import ApoorvaEnvironment

@MainActor @Observable
public class DeveloperSettingsViewModel {
    private let authService: AuthServicing
    private let environmentStore: EnvironmentStore
    private var tools: DeveloperToolsProtocol
    private let remoteConfigService: RemoteConfigServicing
    private let logBuffer: LogBuffer
    private let clearLocalDatabaseAction: () -> Void
    private let terminateAppAction: () -> Void

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
                clearLocalDatabase: @escaping () -> Void,
                terminateApp: @escaping () -> Void) {
        self.authService = authService
        self.environmentStore = environmentStore
        self.tools = tools
        self.remoteConfigService = remoteConfigService
        self.logBuffer = logBuffer
        self.clearLocalDatabaseAction = clearLocalDatabase
        self.terminateAppAction = terminateApp
        self.activeEnvironment = environmentStore.current
        self.pendingEnvironment = environmentStore.current
        self.flagOverrides = tools.flagOverrides
        self.remoteConfigOverrides = tools.remoteConfigOverrides
        self.isOfflineSimulated = tools.isOfflineSimulated
        self.showsScreenIdentifiers = tools.showsScreenIdentifiers
        self.logLines = logBuffer.entries
        self.logText = logBuffer.shareableText
    }

    public private(set) var logLines: [String]
    public private(set) var logText: String
    public var canClearDatabase: Bool { activeEnvironment.allowsDestructiveTools }
    public var canSwitchEnvironment: Bool { pendingEnvironment != activeEnvironment }

    /// Signs out, wipes local state for a clean switch, persists the new environment, then kills the app.
    public func confirmEnvironmentSwitch() {
        print("[DeveloperSettingsViewModel] confirmEnvironmentSwitch: active=\(activeEnvironment) pending=\(pendingEnvironment) canSwitch=\(canSwitchEnvironment)")
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

    public func setRemoteConfigOverride(_ key: String, value: String?) {
        tools.setRemoteConfigOverride(key, value: value)
        remoteConfigOverrides = tools.remoteConfigOverrides
    }

    public func addRemoteConfigOverride(_ key: String, value: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespaces)
        guard !trimmedKey.isEmpty else { return }
        setRemoteConfigOverride(trimmedKey, value: value)
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
        logLines = logBuffer.entries
        logText = logBuffer.shareableText
    }

    public func clearLocalDatabase() {
        guard canClearDatabase else { return }
        clearLocalDatabaseAction()
    }
}
