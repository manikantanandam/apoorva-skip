//
//  RemoteConfigServicing.swift
//  ApoorvaServices
//

import Foundation

/// A single Remote Config default value. Kept as a closed, `Sendable` type (not `Any`) so the
/// abstraction below never leaks a concrete provider's SDK types to call sites.
public enum RemoteConfigDefaultValue: Sendable {
    case bool(Bool)
    case string(String)
    case number(Double)
}

/// Provider-agnostic remote config: swap the conformer, not the call sites.
public protocol RemoteConfigServicing: Sendable {
    func fetchAndActivate() async throws
    func boolValue(forKey key: String) -> Bool
    func stringValue(forKey key: String) -> String?
    func numberValue(forKey key: String) -> Double?
    func setDefaults(_ defaults: [String: RemoteConfigDefaultValue])
}
