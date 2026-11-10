//
//  NoOpCrashReportingService.swift
//  ApoorvaServices
//

public final class NoOpCrashReportingService: CrashReportingServicing {
    public init() {}
    public func recordNonFatal(_ error: Error, context: String) {}
    public func setCustomKey(_ value: String, forKey key: String) {}
    public func setUserId(_ id: String?) {}
    public func log(_ message: String) {}
}
