//
//  PinStore.swift
//  ApoorvaServices
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(Security)
import Security
#endif
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// Per-device staff PINs for the shared-phone switch (design 06). A 4-digit PIN is a convenience
/// gate, not strong security: it's salted and hashed, and never leaves this device.
public protocol PinStoring: Sendable {
    func setPin(_ pin: String, for memberId: String) throws
    func verify(_ pin: String, for memberId: String) -> Bool
    func hasPin(for memberId: String) -> Bool
    func removePin(for memberId: String) throws
}

public final class KeychainPinStore: PinStoring, @unchecked Sendable {
    private let service = "in.apoorva.pin"

    public init() {}

    public func setPin(_ pin: String, for memberId: String) throws {
        let salt = UUID().uuidString
        let record = "\(salt):\(Self.hash(pin, salt: salt))"
        try save(record, account: memberId)
    }

    public func verify(_ pin: String, for memberId: String) -> Bool {
        guard let record = load(account: memberId) else { return false }
        let parts = record.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return false }
        return Self.hash(pin, salt: parts[0]) == parts[1]
    }

    public func hasPin(for memberId: String) -> Bool {
        load(account: memberId) != nil
    }

    public func removePin(for memberId: String) throws {
        #if canImport(Security)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: memberId]
        SecItemDelete(query as CFDictionary)
        #endif
    }

    static func hash(_ pin: String, salt: String) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data((salt + pin).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        return String((salt + pin).hashValue)
        #endif
    }

    private func save(_ value: String, account: String) throws {
        #if canImport(Security)
        try removePin(for: account)
        let attributes: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                         kSecAttrService as String: service,
                                         kSecAttrAccount as String: account,
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                                         kSecValueData as String: Data(value.utf8)]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        #endif
    }

    private func load(account: String) -> String? {
        #if canImport(Security)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
        #else
        return nil
        #endif
    }
}

/// In-memory PIN store for previews and tests.
public final class InMemoryPinStore: PinStoring, @unchecked Sendable {
    private var pins: [String: String] = [:]
    public init() {}
    public func setPin(_ pin: String, for memberId: String) throws { pins[memberId] = pin }
    public func verify(_ pin: String, for memberId: String) -> Bool { pins[memberId] == pin }
    public func hasPin(for memberId: String) -> Bool { pins[memberId] != nil }
    public func removePin(for memberId: String) throws { pins[memberId] = nil }
}

public protocol BiometricAuthenticating: Sendable {
    var isAvailable: Bool { get }
    func authenticate(reason: String) async -> Bool
}

public final class DeviceBiometrics: BiometricAuthenticating, @unchecked Sendable {
    public init() {}

    public var isAvailable: Bool {
        #if canImport(LocalAuthentication)
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        #else
        false
        #endif
    }

    public func authenticate(reason: String) async -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        return (try? await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)) ?? false
        #else
        false
        #endif
    }
}
