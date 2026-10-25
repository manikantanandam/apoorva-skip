//
//  File.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation

@MainActor
public class AppContainer {
    public let servicesContainer = ServicesContainer()
    public let offlineStorageContainer = OfflineStorageContainer()
    public lazy var repositoryContainer = RepositoryContainer(
        servicesContainer: servicesContainer,
        offlineStorageContainer: offlineStorageContainer
    )
    // Feature containers are grouped and lazy-loaded
    public lazy var modulesContainer = ModulesContainer(
        servicesContainer: servicesContainer,
        repositoryContainer: repositoryContainer
    )
    public init() {}
}
