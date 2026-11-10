//
//  CrashReportingServicing.swift
//  ApoorvaServices
//

public protocol CrashReportingServicing: Sendable {
    func recordNonFatal(_ error: Error, context: String)
    func setCustomKey(_ value: String, forKey key: String)
    func setUserId(_ id: String?)
    func log(_ message: String)
}

public extension CrashReportingServicing {
    /// docs/06 requires shopId hashed, never raw, in crash reports.
    func setShopId(_ shopId: String?) {
        setCustomKey(Self.stableHash(shopId), forKey: "shopId")
    }

    func setLaunchContext(appVersion: String, buildFlavor: String) {
        setCustomKey(appVersion, forKey: "appVersion")
        setCustomKey(buildFlavor, forKey: "buildFlavor")
    }

    func leaveBreadcrumb(screen: String, action: String) {
        log("[\(screen)] \(action)")
    }

    /// Pure-Swift FNV-1a hash — not CryptoKit, to stay Android/Skip-portable; this is an opaque
    /// crash-grouping key, not a security boundary.
    static func stableHash(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "none" }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
