//
//  File.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation
import ApoorvaModules
import ApoorvaUtilities

@MainActor
public class AppContainer {
    public let environmentStore = EnvironmentStore()
    public let environment: AppEnvironment
    public let developerTools: DeveloperToolsProtocol = DeveloperTools()
    public let logBuffer = LogBuffer()
    public let servicesContainer = ServicesContainer()
    public let offlineStorageContainer: OfflineStorageContainer
    public lazy var repositoryContainer = RepositoryContainer(
        servicesContainer: servicesContainer,
        offlineStorageContainer: offlineStorageContainer
    )
    // Feature containers are grouped and lazy-loaded
    public lazy var modulesContainer = ModulesContainer(
        servicesContainer: servicesContainer,
        repositoryContainer: repositoryContainer
    )
    public init() {
        let environment = environmentStore.current
        self.environment = environment
        self.offlineStorageContainer = OfflineStorageContainer(environment: environment)
    }

    /// Developer settings are only offered in debug builds.
    public func makeDeveloperSettingsViewModel() -> DeveloperSettingsViewModel? {
        #if DEBUG
        let dbPath = offlineStorageContainer.databasePath
        return DeveloperSettingsViewModel(
            authService: servicesContainer.authService,
            environmentStore: environmentStore,
            tools: developerTools,
            logBuffer: logBuffer,
            clearLocalDatabase: { try? FileManager.default.removeItem(atPath: dbPath) }
        )
        #else
        return nil
        #endif
    }
}
