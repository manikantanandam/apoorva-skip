//
//  NoOpAnalyticsService.swift
//  ApoorvaServices
//

/// For previews and unit tests — never talks to any analytics provider.
public final class NoOpAnalyticsService: AnalyticsServicing {
    public init() {}
    public func log(_ event: AnalyticsEvent) {}
    public func setUserProperty(_ value: String?, forName name: String) {}
    public func setUserId(_ id: String?) {}
    public func setAnalyticsCollectionEnabled(_ enabled: Bool) {}
}
