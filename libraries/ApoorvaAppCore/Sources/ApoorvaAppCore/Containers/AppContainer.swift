//
//  File.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation
import ApoorvaModels
import ApoorvaModules
import ApoorvaUtilities
import ApoorvaEnvironment
import ApoorvaServices
import ManiLogger

private let logger = AppLogger(category: .app)

@MainActor
public class AppContainer {
    public let environmentStore = EnvironmentStore()
    public let environment: AppEnvironment
    public let developerTools: DeveloperToolsProtocol = DeveloperTools()
    public let logBuffer: LogBuffer
    public let fileLogSink: FileLogSink
    public let servicesContainer = ServicesContainer()
    public let offlineStorageContainer: OfflineStorageContainer
    public lazy var repositoryContainer = RepositoryContainer(
        servicesContainer: servicesContainer,
        offlineStorageContainer: offlineStorageContainer
    )
    // Feature containers are grouped and lazy-loaded
    public lazy var modulesContainer = ModulesContainer(
        servicesContainer: servicesContainer,
        repositoryContainer: repositoryContainer,
        environment: environment
    )
    /// The signed-in member's org, store, role, flags and plan — read by every screen.
    public lazy var appSession = AppSession(
        settingsRepository: repositoryContainer.settingsRepository,
        storeRepository: repositoryContainer.storeRepository,
        memberRepository: repositoryContainer.memberRepository,
        saleRepository: repositoryContainer.saleRepository,
        developerTools: developerTools,
        analyticsService: servicesContainer.analyticsService,
        crashReportingService: servicesContainer.crashReportingService,
        appConfig: appConfig
    )

    public let themeStore = ThemeStore()

    /// The single typed read path for app-level config, wrapped with local debug overrides in Debug builds only.
    public lazy var appConfig: AppConfig = {
        #if DEBUG
        AppConfig(
            service: DebugRemoteConfigOverrideService(
                base: servicesContainer.remoteConfigService,
                developerTools: developerTools
            )
        )
        #else
        AppConfig(service: servicesContainer.remoteConfigService)
        #endif
    }()

    /// Whether developer tools are offered (debug builds only).
    public var showsDeveloperTools: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    public var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    public init() {
        let environment = environmentStore.current
        self.environment = environment
        // Sinks are registered before anything else is built so early launch logs are captured.
        let logBuffer = LogBuffer()
        let fileLogSink = FileLogSink(directory: FileLogSink.defaultDirectory())
        LogSinks.shared.configure(
            sinks: [logBuffer, fileLogSink],
            minimumLevel: environment == .production ? .info : .debug
        )
        self.logBuffer = logBuffer
        self.fileLogSink = fileLogSink
        self.offlineStorageContainer = OfflineStorageContainer(environment: environment)
        LogSinks.shared.add(CrashReportingLogSink(crashReportingService: servicesContainer.crashReportingService))
        logger.info("App launched: environment=\(environment) version=\(appVersion) session=\(LogSinks.shared.sessionId)")
        servicesContainer.crashReportingService.setLaunchContext(appVersion: appVersion, buildFlavor: environment.rawValue)
        servicesContainer.analyticsService.setAnalyticsCollectionEnabled(environment == .production)
    }

    /// Developer settings are only offered in debug builds.
    public func makeDeveloperSettingsViewModel() -> DeveloperSettingsViewModel? {
        #if DEBUG
        let dbPath = offlineStorageContainer.databasePath
        return DeveloperSettingsViewModel(
            authService: servicesContainer.authService,
            environmentStore: environmentStore,
            tools: developerTools,
            clearLocalDatabase: {
                try? FileManager.default.removeItem(atPath: dbPath)
                exit(0)
            },
            terminateApp: { exit(0) }
        )
        #else
        return nil
        #endif
    }

    public func makeFlagOverridesViewModel() -> FlagOverridesViewModel? {
        #if DEBUG
        // Unwrapped service: the screen shows the real remote value next to the override.
        return FlagOverridesViewModel(tools: developerTools, remoteConfigService: servicesContainer.remoteConfigService)
        #else
        return nil
        #endif
    }

    public func makeLogViewerViewModel() -> LogViewerViewModel? {
        #if DEBUG
        return LogViewerViewModel(logBuffer: logBuffer, fileLogSink: fileLogSink)
        #else
        return nil
        #endif
    }
}
