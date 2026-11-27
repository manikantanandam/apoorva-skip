//
//  DeveloperSettingsViewModel.swift
//  ApoorvaModules
//

import Foundation
import SkipFuse
import Observation
import ApoorvaModels
import ApoorvaServices
import ApoorvaUtilities
import ApoorvaEnvironment
import ManiLogger

private let logger = AppLogger(category: .app)

@MainActor @Observable
public class DeveloperSettingsViewModel {
    private let authService: AuthServicing
    private let environmentStore: EnvironmentStore
    private var tools: DeveloperToolsProtocol
    private let clearLocalDatabaseAction: () async -> Void
    private let terminateAppAction: () -> Void

    /// Environment the app was launched with; switching only takes effect after relaunch.
    public let activeEnvironment: AppEnvironment
    public var pendingEnvironment: AppEnvironment
    public var errorMessage: String?

    public var isOfflineSimulated: Bool {
        didSet { tools.isOfflineSimulated = isOfflineSimulated }
    }
    public var showsScreenIdentifiers: Bool {
        didSet { tools.showsScreenIdentifiers = showsScreenIdentifiers }
    }

    public init(authService: AuthServicing,
                environmentStore: EnvironmentStore,
                tools: DeveloperToolsProtocol,
                clearLocalDatabase: @escaping () async -> Void,
                terminateApp: @escaping () -> Void) {
        self.authService = authService
        self.environmentStore = environmentStore
        self.tools = tools
        self.clearLocalDatabaseAction = clearLocalDatabase
        self.terminateAppAction = terminateApp
        self.activeEnvironment = environmentStore.current
        self.pendingEnvironment = environmentStore.current
        self.isOfflineSimulated = tools.isOfflineSimulated
        self.showsScreenIdentifiers = tools.showsScreenIdentifiers
    }

    public var canClearDatabase: Bool { activeEnvironment.allowsDestructiveTools }
    public var canSwitchEnvironment: Bool { pendingEnvironment != activeEnvironment }

    /// Signs out, wipes local state for a clean switch, persists the new environment, then kills the app.
    public func confirmEnvironmentSwitch() async {
        logger.info("confirmEnvironmentSwitch: active=\(activeEnvironment) pending=\(pendingEnvironment) canSwitch=\(canSwitchEnvironment)")
        guard canSwitchEnvironment else { return }
        do {
            try authService.logout()
            if activeEnvironment.allowsDestructiveTools {
                await clearLocalDatabaseAction()
            }
            #if !os(Android)
            // removePersistentDomain is unavailable on Android (see docs/decisions/android-readiness.md).
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }
            #endif
            environmentStore.current = pendingEnvironment
            terminateAppAction()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clearLocalDatabase() async {
        guard canClearDatabase else { return }
        await clearLocalDatabaseAction()
        // Restart so in-memory caches (session, view models) don't keep showing the cleared rows.
        terminateAppAction()
    }
}
