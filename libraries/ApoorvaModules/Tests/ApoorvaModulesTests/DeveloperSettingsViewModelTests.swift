//
//  DeveloperSettingsViewModelTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaServices
import ApoorvaEnvironment
import ManiLogger
@testable import ApoorvaModules

@MainActor
struct DeveloperSettingsViewModelTests {
    private func makeViewModel(tools: StubDeveloperTools = StubDeveloperTools())
    -> DeveloperSettingsViewModel {
        DeveloperSettingsViewModel(
            authService: MockAuthService(),
            environmentStore: EnvironmentStore(defaults: UserDefaults(suiteName: "DevSettingsTests-\(UUID().uuidString)")!),
            tools: tools,
            clearLocalDatabase: {},
            terminateApp: {}
        )
    }

    @Test func pendingEnvironmentStartsAtActive() {
        let viewModel = makeViewModel()

        #expect(viewModel.pendingEnvironment == viewModel.activeEnvironment)
        #expect(!viewModel.canSwitchEnvironment)
    }
}
