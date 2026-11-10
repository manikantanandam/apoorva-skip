//
//  NoOpPerformanceMonitoringService.swift
//  ApoorvaServices
//

public final class NoOpPerformanceMonitoringService: PerformanceMonitoringServicing {
    public init() {}
    public func measure<T>(_ traceName: String, _ operation: @Sendable () async throws -> T) async rethrows -> T {
        try await operation()
    }
}
