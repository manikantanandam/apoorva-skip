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

@MainActor @Observable
public class DeveloperSettingsViewModel {
    private let authService: AuthServicing
    private let environmentStore: EnvironmentStore
    private var tools: DeveloperToolsProtocol
    private let clearLocalDatabaseAction: () -> Void
    private let terminateAppAction: () -> Void
    private let backfillDocumentIDsAction: (() async throws -> DocumentIDBackfillResult)?

    /// Environment the app was launched with; switching only takes effect after relaunch.
    public let activeEnvironment: AppEnvironment
    public var pendingEnvironment: AppEnvironment
    public var errorMessage: String?
    public private(set) var isBackfillingDocumentIDs = false
    public private(set) var backfillMessage: String?

    public var isOfflineSimulated: Bool {
        didSet { tools.isOfflineSimulated = isOfflineSimulated }
    }
    public var showsScreenIdentifiers: Bool {
        didSet { tools.showsScreenIdentifiers = showsScreenIdentifiers }
    }

    public init(authService: AuthServicing,
                environmentStore: EnvironmentStore,
                tools: DeveloperToolsProtocol,
                clearLocalDatabase: @escaping () -> Void,
                terminateApp: @escaping () -> Void,
                backfillDocumentIDs: (() async throws -> DocumentIDBackfillResult)? = nil) {
        self.authService = authService
        self.environmentStore = environmentStore
        self.tools = tools
        self.clearLocalDatabaseAction = clearLocalDatabase
        self.terminateAppAction = terminateApp
        self.backfillDocumentIDsAction = backfillDocumentIDs
        self.activeEnvironment = environmentStore.current
        self.pendingEnvironment = environmentStore.current
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

    public func clearLocalDatabase() {
        guard canClearDatabase else { return }
        clearLocalDatabaseAction()
    }

    public var canBackfillDocumentIDs: Bool { backfillDocumentIDsAction != nil }

    /// Adds the missing `id` field (= doc id) to this org's Firestore docs. See `DocumentIDBackfill`.
    public func backfillDocumentIDs() async {
        guard let backfillDocumentIDsAction, !isBackfillingDocumentIDs else { return }
        isBackfillingDocumentIDs = true
        defer { isBackfillingDocumentIDs = false }
        do {
            let result = try await backfillDocumentIDsAction()
            backfillMessage = "Wrote id on \(result.written) sale documents"
        } catch {
            logger.error("Document id backfill failed: \(error.localizedDescription)")
            backfillMessage = "Backfill failed: \(error.localizedDescription)"
        }
    }
}
