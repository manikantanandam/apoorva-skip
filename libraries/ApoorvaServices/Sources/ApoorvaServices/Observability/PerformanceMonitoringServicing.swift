//
//  PerformanceMonitoringServicing.swift
//  ApoorvaServices
//

public protocol PerformanceMonitoringServicing: Sendable {
    func measure<T>(_ traceName: String, _ operation: @Sendable () async throws -> T) async rethrows -> T
}
