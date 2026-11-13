//
//  FlagOverridesViewModelTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaServices
import ApoorvaEnvironment
@testable import ApoorvaModules

@MainActor
struct FlagOverridesViewModelTests {
    private func makeViewModel(remoteConfig: RemoteConfigServicing = NoOpRemoteConfigService(),
                                tools: StubDeveloperTools = StubDeveloperTools()) -> FlagOverridesViewModel {
        FlagOverridesViewModel(tools: tools, remoteConfigService: remoteConfig)
    }

    @Test func unknownKeysCannotBeOverridden() {
        let tools = StubDeveloperTools()
        let viewModel = makeViewModel(tools: tools)

        viewModel.setRemoteConfigOverride("made.up", value: "true")

        #expect(tools.remoteConfigOverrides.isEmpty)
    }

    @Test func staleInventedOverridesArePrunedOnInit() {
        let tools = StubDeveloperTools()
        tools.remoteConfigOverrides = ["made.up": "x", FeatureFlag.holdBills.rawValue: "false"]

        let viewModel = makeViewModel(tools: tools)

        #expect(viewModel.remoteConfigOverrides == [FeatureFlag.holdBills.rawValue: "false"])
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

    @Test func rowIsOnlyMarkedRemoteWhenFirebaseServesTheKey() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults([FeatureFlag.holdBills.rawValue: .bool(true)])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)
        #expect(viewModel.remoteConfigRows.first { $0.id == FeatureFlag.holdBills.rawValue }?.isFromRemote == false)

        remoteConfig.markRemote([FeatureFlag.holdBills.rawValue])
        #expect(viewModel.remoteConfigRows.first { $0.id == FeatureFlag.holdBills.rawValue }?.isFromRemote == true)
    }

    @Test func onChangeFiresWhenOverridesChange() async {
        var changes = 0
        let viewModel = FlagOverridesViewModel(tools: StubDeveloperTools(), remoteConfigService: NoOpRemoteConfigService(),
                                               onChange: { changes += 1 })

        viewModel.setRemoteConfigOverride("min_app_version", value: "9.0.0")
        viewModel.resetRemoteConfigOverrides()
        await viewModel.fetchRemoteConfigNow()

        #expect(changes == 3)
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

    @Test func versionGateOverrideForUnknownKeyIsIgnored() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults(["test.gate": .json(try! JSONEncoder().encode(VersionGateValue(enabled: false)))])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)

        #expect(viewModel.versionGateRemoteValue(forKey: "test.gate") == VersionGateValue(enabled: false))

        // No version-gated flag exists in the catalogue yet, so an override can't be created for this key.
        viewModel.setVersionGateOverride(key: "test.gate", value: VersionGateValue(enabled: true, minVersion: "2.3.0"))
        #expect(viewModel.versionGateOverrideValue(forKey: "test.gate") == nil)
    }
}
