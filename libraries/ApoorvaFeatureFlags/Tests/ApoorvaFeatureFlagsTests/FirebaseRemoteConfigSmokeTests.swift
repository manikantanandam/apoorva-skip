//
//  FirebaseRemoteConfigSmokeTests.swift
//  ApoorvaFeatureFlags
//
//  Runs the thin `FirebaseRemoteConfigBackend` adapter against a configured-but-fake Firebase app
//  so its SDK calls execute. Nothing here asserts server behaviour.
//

import Testing
import Foundation
import FirebaseCore
@testable import ApoorvaFeatureFlags

private let configureFirebase: Void = {
    if FirebaseApp.app() == nil {
        let options = FirebaseOptions(googleAppID: "1:1234567890:ios:0123456789abcdef", gcmSenderID: "1234567890")
        // Firebase Installations validates the format: 39 characters, starting with "A".
        options.apiKey = "AIzaSy000000000000000000000000000000000"
        options.projectID = "fake-project"
        FirebaseApp.configure(options: options)
    }
}()

@Suite(.serialized)
struct FirebaseRemoteConfigSmokeTests {
    @Test func remoteConfigAdapterReadsDefaults() {
        _ = configureFirebase
        let service = FirebaseRemoteConfigService(minimumFetchInterval: 0)
        service.setDefaults(["b": .bool(true), "s": .string("x"), "n": .number(2)])
        #expect(service.boolValue(forKey: "b"))
        #expect(service.stringValue(forKey: "s") == "x")
        #expect(service.numberValue(forKey: "n") == 2)
        #expect(!service.isRemoteValue(forKey: "s"))
        #expect(FirebaseRemoteConfigBackend().remoteKeys().isEmpty)
        _ = service.resolvedEntries()
        Task { try? await service.fetchAndActivate() }
    }
}
