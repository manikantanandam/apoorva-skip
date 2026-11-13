//
//  RemoteConfigLogFormatterTests.swift
//  ApoorvaServices
//

import Testing
@testable import ApoorvaServices

struct RemoteConfigLogFormatterTests {
    @Test func summaryListsOnlyFirebaseValuesAndCountsDefaults() {
        let summary = RemoteConfigLogFormatter.summary([
            RemoteConfigLogEntry(key: "min_app_version", value: "2.0.0", source: .remote),
            RemoteConfigLogEntry(key: "hold_bills", value: "true", source: .default),
            RemoteConfigLogEntry(key: "orders", value: "true", source: .default)
        ])

        #expect(summary == "Remote Config values from Firebase: min_app_version=2.0.0 (2 keys using compiled defaults)")
    }

    @Test func noFirebaseValuesReportsOnlyDefaultCount() {
        let summary = RemoteConfigLogFormatter.summary([
            RemoteConfigLogEntry(key: "hold_bills", value: "true", source: .default)
        ])

        #expect(summary == "Remote Config: no values from Firebase (1 keys using compiled defaults)")
    }

    @Test func flagsFirebaseKeysMissingFromTheCatalogue() {
        let summary = RemoteConfigLogFormatter.summary([
            RemoteConfigLogEntry(key: "min_version", value: "2.0.0", source: .remote, isInCatalogue: false),
            RemoteConfigLogEntry(key: "min_app_version", value: "1.0.0", source: .default)
        ])

        #expect(summary == "Remote Config values from Firebase: min_version=2.0.0 [not in app catalogue] (1 keys using compiled defaults)")
    }
}
