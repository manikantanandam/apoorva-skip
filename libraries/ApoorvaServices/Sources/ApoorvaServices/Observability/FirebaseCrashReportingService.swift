//
//  FirebaseCrashReportingService.swift
//  ApoorvaServices
//

import FirebaseCrashlytics

/// Thin seam over `Crashlytics` so the key/user mapping can be tested without Firebase.
protocol CrashlyticsBackend: Sendable {
    func record(_ error: Error)
    func setCustomValue(_ value: String, forKey key: String)
    func setUserID(_ id: String)
    func log(_ message: String)
}

public final class FirebaseCrashReportingService: CrashReportingServicing {

    private let backend: CrashlyticsBackend

    public convenience init() {
        self.init(backend: FirebaseCrashlyticsBackend())
    }

    init(backend: CrashlyticsBackend) {
        self.backend = backend
    }

    public func recordNonFatal(_ error: Error, context: String) {
        // Last non-fatal context only — not cleared, so a later fatal or unrelated
        // non-fatal may still carry a stale value here.
        backend.setCustomValue(context, forKey: "lastErrorContext")
        backend.record(error)
    }

    public func setCustomKey(_ value: String, forKey key: String) {
        backend.setCustomValue(value, forKey: key)
    }

    public func setUserId(_ id: String?) {
        backend.setUserID(id ?? "")
    }

    public func log(_ message: String) {
        backend.log(message)
    }
}

// MARK: - Firebase adapter (SDK calls only, no logic)

struct FirebaseCrashlyticsBackend: CrashlyticsBackend {
    func record(_ error: Error) { Crashlytics.crashlytics().record(error: error) }
    func setCustomValue(_ value: String, forKey key: String) { Crashlytics.crashlytics().setCustomValue(value, forKey: key) }
    func setUserID(_ id: String) { Crashlytics.crashlytics().setUserID(id) }
    func log(_ message: String) { Crashlytics.crashlytics().log(message) }
}
