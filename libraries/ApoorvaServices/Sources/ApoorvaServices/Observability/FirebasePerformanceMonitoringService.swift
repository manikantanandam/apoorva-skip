//
//  FirebasePerformanceMonitoringService.swift
//  ApoorvaServices
//

import FirebasePerformance

/// Thin seam over `Performance` so the trace lifecycle can be tested without Firebase.
protocol PerformanceTraceBackend: Sendable {
    /// Starts a trace; the returned closure stops it (nil when Firebase declined to create one).
    func startTrace(_ name: String) -> (@Sendable () -> Void)?
}

public final class FirebasePerformanceMonitoringService: PerformanceMonitoringServicing {

    private let backend: PerformanceTraceBackend

    public convenience init() {
        self.init(backend: FirebasePerformanceBackend())
    }

    init(backend: PerformanceTraceBackend) {
        self.backend = backend
    }

    public func measure<T>(_ traceName: String, _ operation: @Sendable () async throws -> T) async rethrows -> T {
        let stop = backend.startTrace(traceName)
        defer { stop?() }
        return try await operation()
    }
}

// MARK: - Firebase adapter (SDK calls only, no logic)

private struct SendableTrace: @unchecked Sendable {
    let value: Trace
}

struct FirebasePerformanceBackend: PerformanceTraceBackend {
    func startTrace(_ name: String) -> (@Sendable () -> Void)? {
        guard let trace = Performance.startTrace(name: name) else { return nil }
        let sendable = SendableTrace(value: trace)
        return { sendable.value.stop() }
    }
}
