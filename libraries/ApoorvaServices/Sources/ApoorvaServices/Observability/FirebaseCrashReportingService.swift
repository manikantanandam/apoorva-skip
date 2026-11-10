//
//  FirebaseCrashReportingService.swift
//  ApoorvaServices
//

import FirebaseCrashlytics

public final class FirebaseCrashReportingService: CrashReportingServicing {

    public init() {}

    public func recordNonFatal(_ error: Error, context: String) {
        Crashlytics.crashlytics().setCustomValue(context, forKey: "lastErrorContext")
        Crashlytics.crashlytics().record(error: error)
    }

    public func setCustomKey(_ value: String, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    public func setUserId(_ id: String?) {
        Crashlytics.crashlytics().setUserID(id ?? "")
    }

    public func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }
}
