//
//  FlagOverridesViewModel.swift
//  ApoorvaModules
//

import Foundation
import Observation
import ApoorvaModels
import ApoorvaServices
import ApoorvaEnvironment

/// One row of the catalogue-driven Remote Config list in Developer Settings: the live remote
/// value, plus the local override if one is set.
public struct RemoteConfigRowDisplay: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let kind: RemoteConfigValueKind
    public let remoteDisplayValue: String
    /// False when Firebase has no value for the key and the compiled default is showing.
    public let isFromRemote: Bool
    public let overrideValue: String?
    public var isOverridden: Bool { overrideValue != nil }
    public var effectiveDisplayValue: String { overrideValue ?? remoteDisplayValue }
}

/// Backs `FlagOverridesView`: local feature-flag overrides and Remote Config overrides.
@MainActor @Observable
public class FlagOverridesViewModel {
    private let tools: DeveloperToolsProtocol
    private let remoteConfigService: RemoteConfigServicing
    /// Called after anything that can change an effective flag value, so the app can re-evaluate (e.g. force update).
    private let onChange: () -> Void

    public var errorMessage: String?
    public var flagOverrides: [String: Bool]
    public var remoteConfigOverrides: [String: String]

    public init(tools: DeveloperToolsProtocol, remoteConfigService: RemoteConfigServicing,
                onChange: @escaping () -> Void = {}) {
        self.tools = tools
        self.remoteConfigService = remoteConfigService
        self.onChange = onChange
        self.flagOverrides = tools.flagOverrides
        self.remoteConfigOverrides = tools.remoteConfigOverrides
    }

    public func setFlag(_ key: String, value: Bool?) {
        tools.setFlagOverride(key, value: value)
        flagOverrides = tools.flagOverrides
        onChange()
    }

    public func addFlag(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        setFlag(trimmed, value: true)
    }

    public func resetFlags() {
        tools.clearFlagOverrides()
        flagOverrides = [:]
        onChange()
    }

    /// The locally declared Remote Config keys with their live remote value and, if set, override.
    public var remoteConfigRows: [RemoteConfigRowDisplay] {
        RemoteConfigCatalog.all.map { definition in
            let remoteDisplay = Self.displayValue(forRemote: definition, service: remoteConfigService)
            let overrideDisplay = remoteConfigOverrides[definition.key].map { raw in
                Self.displayValue(forOverrideRaw: raw, kind: definition.kind)
            }
            return RemoteConfigRowDisplay(id: definition.key, title: definition.title, kind: definition.kind,
                                           remoteDisplayValue: remoteDisplay, isFromRemote: remoteConfigService.isRemoteValue(forKey: definition.key),
                                           overrideValue: overrideDisplay)
        }
    }

    private static func displayValue(forRemote definition: RemoteConfigKeyDefinition, service: RemoteConfigServicing) -> String {
        switch definition.kind {
        case .bool: return service.boolValue(forKey: definition.key) ? "On" : "Off"
        case .string: return service.stringValue(forKey: definition.key) ?? definition.defaultString
        case .number: return formatted(service.numberValue(forKey: definition.key) ?? definition.defaultNumber)
        case .versionGate: return formatted(service.jsonValue(forKey: definition.key, as: VersionGateValue.self) ?? definition.defaultVersionGate)
        }
    }

    private static func displayValue(forOverrideRaw raw: String, kind: RemoteConfigValueKind) -> String {
        switch kind {
        case .bool: return (Bool(raw) ?? false) ? "On" : "Off"
        case .string, .number: return raw
        case .versionGate:
            guard let data = raw.data(using: .utf8), let gate = try? JSONDecoder().decode(VersionGateValue.self, from: data) else { return raw }
            return formatted(gate)
        }
    }

    private static func formatted(_ number: Double) -> String {
        number == number.rounded() ? String(Int(number)) : String(number)
    }

    private static func formatted(_ gate: VersionGateValue) -> String {
        guard gate.enabled else { return "Off" }
        guard let minVersion = gate.minVersion else { return "On" }
        return "On ≥ \(minVersion)"
    }

    public func setRemoteConfigOverride(_ key: String, value: String?) {
        tools.setRemoteConfigOverride(key, value: value)
        remoteConfigOverrides = tools.remoteConfigOverrides
        onChange()
    }

    /// Validates `rawValue` against `row.kind` before storing it as the override.
    /// Returns `false` (and makes no change) when the text doesn't parse for that kind.
    @discardableResult
    public func setRemoteConfigOverride(for row: RemoteConfigRowDisplay, rawValue: String) -> Bool {
        switch row.kind {
        case .bool:
            guard let bool = Bool(rawValue) else { return false }
            setRemoteConfigOverride(row.id, value: bool ? "true" : "false")
        case .string:
            setRemoteConfigOverride(row.id, value: rawValue)
        case .number:
            guard Double(rawValue) != nil else { return false }
            setRemoteConfigOverride(row.id, value: rawValue)
        case .versionGate:
            // Edited via `setVersionGateOverride`, not this raw-text path.
            return false
        }
        return true
    }

    public func versionGateRemoteValue(forKey key: String) -> VersionGateValue {
        let defaultValue = RemoteConfigCatalog.all.first { $0.key == key }?.defaultVersionGate ?? VersionGateValue(enabled: false)
        return remoteConfigService.jsonValue(forKey: key, as: VersionGateValue.self) ?? defaultValue
    }

    public func versionGateOverrideValue(forKey key: String) -> VersionGateValue? {
        guard let raw = remoteConfigOverrides[key], let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(VersionGateValue.self, from: data)
    }

    public func setVersionGateOverride(key: String, value: VersionGateValue) {
        guard let data = try? JSONEncoder().encode(value), let json = String(data: data, encoding: .utf8) else { return }
        setRemoteConfigOverride(key, value: json)
    }

    public func resetRemoteConfigOverrides() {
        tools.clearRemoteConfigOverrides()
        remoteConfigOverrides = [:]
        onChange()
    }

    public func fetchRemoteConfigNow() async {
        do {
            try await remoteConfigService.fetchAndActivate()
            onChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
