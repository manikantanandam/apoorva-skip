//
//  AnalyticsServicing.swift
//  ApoorvaServices
//

import Foundation

/// A single analytics parameter value. Kept as a closed, `Sendable` type (not `Any`) so the
/// abstraction below never leaks a concrete provider's SDK types to call sites.
public enum AnalyticsParameterValue: Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}

/// A provider-neutral analytics event. Names/params follow docs/06 §2b's schema.
public struct AnalyticsEvent: Sendable {
    public let name: String
    public let parameters: [String: AnalyticsParameterValue]

    public init(name: String, parameters: [String: AnalyticsParameterValue] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}

public extension AnalyticsEvent {
    static func signInMethod(_ method: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "sign_in_method", parameters: ["method": .string(method)])
    }

    static func billSaved(itemCount: Int, mode: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "bill_saved", parameters: ["item_count": .int(itemCount), "mode": .string(mode)])
    }

    static func trialStarted(days: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "trial_started", parameters: ["days": .int(days)])
    }

    /// Defined for schema completeness; no real purchase/upgrade flow exists yet to call it from.
    static func subscribed(plan: String, period: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "subscribed", parameters: ["plan": .string(plan), "period": .string(period)])
    }
}

/// Provider-agnostic event tracking: swap the conformer, not the call sites.
public protocol AnalyticsServicing: Sendable {
    func log(_ event: AnalyticsEvent)
    func setUserProperty(_ value: String?, forName name: String)
    func setUserId(_ id: String?)
    func setAnalyticsCollectionEnabled(_ enabled: Bool)
}

public extension AnalyticsServicing {
    func logScreenView(_ screenName: String) {
        log(AnalyticsEvent(name: "screen_view", parameters: ["screen_name": .string(screenName)]))
    }
}
