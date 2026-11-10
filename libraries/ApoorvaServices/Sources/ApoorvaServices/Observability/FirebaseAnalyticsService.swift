//
//  FirebaseAnalyticsService.swift
//  ApoorvaServices
//

import FirebaseAnalytics

public final class FirebaseAnalyticsService: AnalyticsServicing {

    public init() {}

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
        Analytics.logEvent(event.name, parameters: parameters.isEmpty ? nil : parameters)
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    public func setUserId(_ id: String?) {
        Analytics.setUserID(id)
    }

    public func setAnalyticsCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }
}
