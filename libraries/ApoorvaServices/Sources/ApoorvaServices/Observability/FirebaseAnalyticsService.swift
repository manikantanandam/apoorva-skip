//
//  FirebaseAnalyticsService.swift
//  ApoorvaServices
//

import FirebaseAnalytics

/// Thin seam over `FirebaseAnalytics` so the parameter mapping can be tested without Firebase.
protocol AnalyticsBackend: Sendable {
    func logEvent(_ name: String, parameters: [String: Any]?)
    func setUserProperty(_ value: String?, forName name: String)
    func setUserID(_ id: String?)
    func setCollectionEnabled(_ enabled: Bool)
}

public final class FirebaseAnalyticsService: AnalyticsServicing {

    private let backend: AnalyticsBackend

    public convenience init() {
        self.init(backend: FirebaseAnalyticsBackend())
    }

    init(backend: AnalyticsBackend) {
        self.backend = backend
    }

    public func log(_ event: AnalyticsEvent) {
        var parameters: [String: Any] = [:]
        for (key, value) in event.parameters {
            switch value {
            case .string(let string): parameters[key] = string
            case .int(let int): parameters[key] = int
            case .double(let double): parameters[key] = double
            case .bool(let bool): parameters[key] = bool
            }
        }
        backend.logEvent(event.name, parameters: parameters.isEmpty ? nil : parameters)
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        backend.setUserProperty(value, forName: name)
    }

    public func setUserId(_ id: String?) {
        backend.setUserID(id)
    }

    public func setAnalyticsCollectionEnabled(_ enabled: Bool) {
        backend.setCollectionEnabled(enabled)
    }
}

// MARK: - Firebase adapter (SDK calls only, no logic)

struct FirebaseAnalyticsBackend: AnalyticsBackend {
    func logEvent(_ name: String, parameters: [String: Any]?) { Analytics.logEvent(name, parameters: parameters) }
    func setUserProperty(_ value: String?, forName name: String) { Analytics.setUserProperty(value, forName: name) }
    func setUserID(_ id: String?) { Analytics.setUserID(id) }
    func setCollectionEnabled(_ enabled: Bool) { Analytics.setAnalyticsCollectionEnabled(enabled) }
}
