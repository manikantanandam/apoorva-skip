//
//  FlagOverridesViewModelTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaFeatureFlags
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
        tools.remoteConfigOverrides = ["made.up": "x", "orders": "{\"enabled\":false}"]

        let viewModel = makeViewModel(tools: tools)

        #expect(viewModel.remoteConfigOverrides == ["orders": "{\"enabled\":false}"])
    }

    /// `orders`/`suppliers`/`expenses` briefly shared a `misc` catch-all before getting their own
    /// dedicated groups — a value stored at `misc` by that older build is stale now that nothing
    /// maps to `misc` any more.
    @Test func staleMiscGroupKeyIsPrunedOnInit() {
        let tools = StubDeveloperTools()
        tools.remoteConfigOverrides = ["misc": "{\"orders\":false}"]

        let viewModel = makeViewModel(tools: tools)

        #expect(viewModel.remoteConfigOverrides.isEmpty)
    }

    /// A grouped flag's own dotted key (e.g. "billing.hold_bills") may have been persisted by a
    /// pre-grouping build; it's no longer a valid storage key now that siblings share "billing".
    @Test func staleFlatKeyForGroupedFlagIsPrunedOnInit() {
        let tools = StubDeveloperTools()
        tools.remoteConfigOverrides = [FeatureFlag.holdBills.rawValue: "false"]

        let viewModel = makeViewModel(tools: tools)

        #expect(viewModel.remoteConfigOverrides.isEmpty)
    }

    @Test func rowShowsRemoteValueWhenNotOverridden() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults(["orders": .json(try! JSONEncoder().encode(["enabled": true]))])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)

        let row = viewModel.remoteConfigRows.first { $0.id == FeatureFlag.orders.rawValue }
        #expect(row?.remoteDisplayValue == "On")
        #expect(row?.isOverridden == false)
        #expect(row?.effectiveDisplayValue == "On")
    }

    @Test func rowIsOnlyMarkedRemoteWhenFirebaseServesTheKey() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults(["orders": .json(try! JSONEncoder().encode(["enabled": true]))])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)
        #expect(viewModel.remoteConfigRows.first { $0.id == FeatureFlag.orders.rawValue }?.isFromRemote == false)

        remoteConfig.markRemote(["orders"])
        #expect(viewModel.remoteConfigRows.first { $0.id == FeatureFlag.orders.rawValue }?.isFromRemote == true)
    }

    @Test func groupedFlagReadsFromSharedJSONParameter() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults(["billing": .json(try! JSONEncoder().encode(["hold_bills": false, "returns": true]))])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)

        #expect(viewModel.remoteConfigRows.first { $0.id == FeatureFlag.holdBills.rawValue }?.remoteDisplayValue == "Off")
        #expect(viewModel.remoteConfigRows.first { $0.id == FeatureFlag.returns.rawValue }?.remoteDisplayValue == "On")
    }

    @Test func isFromRemoteIsSharedAcrossGroupSiblings() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults(["billing": .json(try! JSONEncoder().encode(["hold_bills": true, "returns": true]))])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)
        #expect(viewModel.remoteConfigRows.first { $0.id == FeatureFlag.holdBills.rawValue }?.isFromRemote == false)

        remoteConfig.markRemote(["billing"])
        #expect(viewModel.remoteConfigRows.first { $0.id == FeatureFlag.holdBills.rawValue }?.isFromRemote == true)
        #expect(viewModel.remoteConfigRows.first { $0.id == FeatureFlag.returns.rawValue }?.isFromRemote == true)
    }

    @Test func overridingOneGroupedFieldDoesNotMarkSiblingAsOverridden() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults(["billing": .json(try! JSONEncoder().encode(["hold_bills": true, "returns": true]))])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)

        viewModel.setRemoteConfigOverride(FeatureFlag.holdBills.rawValue, value: "false")

        let holdBillsRow = viewModel.remoteConfigRows.first { $0.id == FeatureFlag.holdBills.rawValue }
        let returnsRow = viewModel.remoteConfigRows.first { $0.id == FeatureFlag.returns.rawValue }
        #expect(holdBillsRow?.isOverridden == true)
        #expect(holdBillsRow?.effectiveDisplayValue == "Off")
        #expect(returnsRow?.isOverridden == false)
        #expect(returnsRow?.effectiveDisplayValue == "On")
    }

    @Test func clearingOneGroupedOverridePreservesSiblingOverride() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults(["billing": .json(try! JSONEncoder().encode(["hold_bills": true, "returns": true]))])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)

        viewModel.setRemoteConfigOverride(FeatureFlag.holdBills.rawValue, value: "false")
        viewModel.setRemoteConfigOverride(FeatureFlag.returns.rawValue, value: "false")

        viewModel.setRemoteConfigOverride(FeatureFlag.holdBills.rawValue, value: nil)

        let holdBillsRow = viewModel.remoteConfigRows.first { $0.id == FeatureFlag.holdBills.rawValue }
        let returnsRow = viewModel.remoteConfigRows.first { $0.id == FeatureFlag.returns.rawValue }
        #expect(holdBillsRow?.isOverridden == false)
        #expect(holdBillsRow?.effectiveDisplayValue == "On")
        #expect(returnsRow?.isOverridden == true)
        #expect(returnsRow?.effectiveDisplayValue == "Off")
    }

    @Test func overridingGroupedFlagBackToBaselineClearsTheOverride() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults(["billing": .json(try! JSONEncoder().encode(["hold_bills": true, "returns": true]))])
        let tools = StubDeveloperTools()
        let viewModel = makeViewModel(remoteConfig: remoteConfig, tools: tools)

        viewModel.setRemoteConfigOverride(FeatureFlag.holdBills.rawValue, value: "false")
        #expect(tools.remoteConfigOverrides["billing"] != nil)

        viewModel.setRemoteConfigOverride(FeatureFlag.holdBills.rawValue, value: "true")
        #expect(tools.remoteConfigOverrides["billing"] == nil)
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
        remoteConfig.setDefaults(["orders": .json(try! JSONEncoder().encode(["enabled": true]))])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)

        viewModel.setRemoteConfigOverride(FeatureFlag.orders.rawValue, value: "false")
        let row = viewModel.remoteConfigRows.first { $0.id == FeatureFlag.orders.rawValue }
        #expect(row?.remoteDisplayValue == "On")
        #expect(row?.isOverridden == true)
        #expect(row?.effectiveDisplayValue == "Off")
    }

    @Test func overridingBackToRemoteValueClearsTheOverride() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults(["orders": .json(try! JSONEncoder().encode(["enabled": true]))])
        let tools = StubDeveloperTools()
        let viewModel = makeViewModel(remoteConfig: remoteConfig, tools: tools)
        let key = FeatureFlag.orders.rawValue

        viewModel.setRemoteConfigOverride(key, value: "false")
        #expect(viewModel.remoteConfigRows.first { $0.id == key }?.isOverridden == true)

        viewModel.setRemoteConfigOverride(key, value: "true")
        #expect(viewModel.remoteConfigRows.first { $0.id == key }?.isOverridden == false)
        #expect(tools.remoteConfigOverrides.isEmpty)
    }

    @Test func stringOverrideEqualToRemoteValueIsNotStored() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults([FeatureFlag.minAppVersion.rawValue: .string("2.0.0")])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)
        guard let row = viewModel.remoteConfigRows.first(where: { $0.id == "min_app_version" }) else {
            Issue.record("expected min_app_version in the catalogue")
            return
        }

        #expect(viewModel.setRemoteConfigOverride(for: row, rawValue: "2.0.0"))
        #expect(viewModel.remoteConfigRows.first { $0.id == "min_app_version" }?.isOverridden == false)
    }

    @Test func clearingOverrideStillNotifiesChange() {
        var changes = 0
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults(["orders": .json(try! JSONEncoder().encode(["enabled": true]))])
        let viewModel = FlagOverridesViewModel(tools: StubDeveloperTools(), remoteConfigService: remoteConfig,
                                               onChange: { changes += 1 })

        viewModel.setRemoteConfigOverride(FeatureFlag.orders.rawValue, value: "true")

        #expect(changes == 1)
    }

    @Test func resetRevertsToRemoteValue() {
        let remoteConfig = NoOpRemoteConfigService()
        remoteConfig.setDefaults(["orders": .json(try! JSONEncoder().encode(["enabled": true]))])
        let viewModel = makeViewModel(remoteConfig: remoteConfig)

        viewModel.setRemoteConfigOverride(FeatureFlag.orders.rawValue, value: "false")
        viewModel.resetRemoteConfigOverrides()
        let row = viewModel.remoteConfigRows.first { $0.id == FeatureFlag.orders.rawValue }
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
