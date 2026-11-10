//
//  FirebasePerformanceMonitoringService.swift
//  ApoorvaServices
//

import FirebasePerformance

public final class FirebasePerformanceMonitoringService: PerformanceMonitoringServicing {

    public init() {}

    public func measure<T>(_ traceName: String, _ operation: @Sendable () async throws -> T) async rethrows -> T {
        let trace = Performance.startTrace(name: traceName)
        defer { trace?.stop() }
        return try await operation()
    }
}
