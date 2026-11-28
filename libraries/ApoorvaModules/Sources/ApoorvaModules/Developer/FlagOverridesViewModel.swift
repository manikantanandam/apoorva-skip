//
//  FlagOverridesViewModel.swift
//  ApoorvaModules
//

import Foundation
import SkipFuse
import Observation
import ApoorvaFeatureFlags
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

/// Backs `FlagOverridesView`: local overrides of the existing Remote Config catalogue keys.
@MainActor @Observable
public class FlagOverridesViewModel {
    private let tools: DeveloperToolsProtocol
    private let remoteConfigService: RemoteConfigServicing
    /// Called after anything that can change an effective flag value, so the app can re-evaluate (e.g. force update).
    private let onChange: () -> Void

    public var errorMessage: String?
    public var remoteConfigOverrides: [String: String]

    public init(tools: DeveloperToolsProtocol, remoteConfigService: RemoteConfigServicing,
                onChange: @escaping () -> Void = {}) {
        self.tools = tools
        self.remoteConfigService = remoteConfigService
        self.onChange = onChange
        // Overrides may only target keys that exist; drop any invented keys persisted by older builds.
        for key in tools.remoteConfigOverrides.keys where !Self.isKnownRemoteConfigKey(key) {
            tools.setRemoteConfigOverride(key, value: nil)
        }
        self.remoteConfigOverrides = tools.remoteConfigOverrides
    }

    /// A key is known when it's a Remote Config parameter the current code actually reads/writes:
    /// an ungrouped flag's own key, or the shared group key for a dot-namespaced bool flag — never
    /// a grouped flag's own dotted key, which pre-migration builds may have persisted but which is
    /// no longer a valid storage location (dropped as an "invented key persisted by an older build").
    private static func isKnownRemoteConfigKey(_ key: String) -> Bool {
        RemoteConfigCatalog.all.contains { $0.remoteConfigParameterKey == key }
    }

    /// The locally declared Remote Config keys with their live remote value and, if set, override.
    public var remoteConfigRows: [RemoteConfigRowDisplay] {
        RemoteConfigCatalog.all.map { definition in
            let remoteDisplay = Self.displayValue(forRemote: definition, service: remoteConfigService)
            return RemoteConfigRowDisplay(id: definition.key, title: definition.title, kind: definition.kind,
                                           remoteDisplayValue: remoteDisplay,
                                           isFromRemote: remoteConfigService.isRemoteValue(forKey: definition.remoteConfigParameterKey),
                                           overrideValue: overrideDisplayValue(for: definition))
        }
    }

    private static func displayValue(forRemote definition: RemoteConfigKeyDefinition, service: RemoteConfigServicing) -> String {
        switch definition.kind {
        case .bool: return AppConfig.resolveBool(definition, from: service) ? "On" : "Off"
        case .string: return service.stringValue(forKey: definition.key) ?? definition.defaultString
        case .number: return formatted(service.numberValue(forKey: definition.key) ?? definition.defaultNumber)
        case .versionGate: return formatted(service.jsonValue(forKey: definition.key, as: VersionGateValue.self) ?? definition.defaultVersionGate)
        }
    }

    /// The override display string for one row: for a grouped flag, that field's value in the
    /// shared group blob — but only when it actually differs from the live remote/default
    /// baseline. Overriding one field pins the *whole* group's snapshot into storage (Remote
    /// Config overrides a parameter's value atomically), so an untouched sibling is still present
    /// in the blob at its unchanged value; comparing against the baseline is what distinguishes
    /// "actually overridden" from "merely carried along in the snapshot".
    private func overrideDisplayValue(for definition: RemoteConfigKeyDefinition) -> String? {
        guard let group = definition.remoteConfigGroupKey else {
            guard let raw = remoteConfigOverrides[definition.key] else { return nil }
            return Self.displayValue(forOverrideRaw: raw, kind: definition.kind)
        }
        let overridden = decodedGroupOverride(group: group)
        guard let storedValue = overridden[definition.remoteConfigFieldName],
              storedValue != AppConfig.resolveBool(definition, from: remoteConfigService) else { return nil }
        return storedValue ? "On" : "Off"
    }

    /// Decodes the group's stored override blob, or `[:]` if there isn't one (or it's unparsable).
    private func decodedGroupOverride(group: String) -> [String: Bool] {
        guard let raw = remoteConfigOverrides[group], let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else { return [:] }
        return decoded
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

    /// Setting a value equal to what Firebase (or the compiled default) already serves clears the override.
    public func setRemoteConfigOverride(_ key: String, value: String?) {
        guard let definition = RemoteConfigCatalog.all.first(where: { $0.key == key }) else { return }
        if let group = definition.remoteConfigGroupKey {
            setGroupFieldOverride(definition: definition, group: group, rawValue: value)
            return
        }
        let stored = value.flatMap { matchesRemote(key, $0) ? nil : $0 }
        tools.setRemoteConfigOverride(key, value: stored)
        remoteConfigOverrides = tools.remoteConfigOverrides
        onChange()
    }

    /// Remote Config groups are read/overridden as one JSON object, so overriding one field
    /// necessarily carries its siblings' current values along — overriding one field in a group
    /// pins the whole group's snapshot until that field is cleared or all overrides are reset.
    /// (`overrideDisplayValue` is what keeps an untouched sibling from *showing* as overridden.)
    private func setGroupFieldOverride(definition: RemoteConfigKeyDefinition, group: String, rawValue: String?) {
        var merged = effectiveGroupValues(group: group)
        if let rawValue, let newBool = Bool(rawValue) {
            merged[definition.remoteConfigFieldName] = newBool
        } else {
            // Clear: reset just this field to its remote/default value, keep siblings' overrides.
            merged[definition.remoteConfigFieldName] = AppConfig.resolveBool(definition, from: remoteConfigService)
        }
        storeGroupOverride(group: group, values: merged)
    }

    /// Current effective (override-if-set, else remote, else compiled default) value for every
    /// sibling field in `group`.
    private func effectiveGroupValues(group: String) -> [String: Bool] {
        let overridden = decodedGroupOverride(group: group)
        let siblings = RemoteConfigCatalog.all.filter { $0.remoteConfigGroupKey == group }
        return Dictionary(uniqueKeysWithValues: siblings.map { sibling in
            (sibling.remoteConfigFieldName, overridden[sibling.remoteConfigFieldName] ?? AppConfig.resolveBool(sibling, from: remoteConfigService))
        })
    }

    /// Stores the merged blob, or clears the override entirely if it now matches the no-override
    /// baseline for every field in the group.
    private func storeGroupOverride(group: String, values: [String: Bool]) {
        let siblings = RemoteConfigCatalog.all.filter { $0.remoteConfigGroupKey == group }
        let baseline = Dictionary(uniqueKeysWithValues: siblings.map {
            ($0.remoteConfigFieldName, AppConfig.resolveBool($0, from: remoteConfigService))
        })
        let stored: String? = values == baseline ? nil : encodeJSON(values)
        tools.setRemoteConfigOverride(group, value: stored)
        remoteConfigOverrides = tools.remoteConfigOverrides
        onChange()
    }

    private func encodeJSON(_ values: [String: Bool]) -> String? {
        guard let data = try? JSONEncoder().encode(values), let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }

    private func matchesRemote(_ key: String, _ raw: String) -> Bool {
        guard let definition = RemoteConfigCatalog.all.first(where: { $0.key == key }) else { return false }
        switch definition.kind {
        case .bool:
            return Bool(raw) == remoteConfigService.boolValue(forKey: key)
        case .string:
            return raw == (remoteConfigService.stringValue(forKey: key) ?? definition.defaultString)
        case .number:
            return Double(raw) == (remoteConfigService.numberValue(forKey: key) ?? definition.defaultNumber)
        case .versionGate:
            guard let data = raw.data(using: .utf8), let gate = try? JSONDecoder().decode(VersionGateValue.self, from: data) else { return false }
            return gate == (remoteConfigService.jsonValue(forKey: key, as: VersionGateValue.self) ?? definition.defaultVersionGate)
        }
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
