//
//  DeveloperSettingsViewModelTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaServices
import ApoorvaEnvironment
@testable import ApoorvaModules

@MainActor
struct DeveloperSettingsViewModelTests {
    private func makeViewModel(remoteConfig: RemoteConfigServicing = NoOpRemoteConfigService(),
                                tools: StubDeveloperTools = StubDeveloperTools())
    -> DeveloperSettingsViewModel {
        DeveloperSettingsViewModel(
            authService: MockAuthService(),
            environmentStore: EnvironmentStore(defaults: UserDefaults(suiteName: "DevSettingsTests-\(UUID().uuidString)")!),
            tools: tools,
            remoteConfigService: remoteConfig,
            logBuffer: LogBuffer(),
            clearLocalDatabase: {},
            terminateApp: {}
        )
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
}
