//
//  FirebaseRemoteConfigServiceTests.swift
//  ApoorvaFeatureFlags
//

import Testing
import Foundation
@testable import ApoorvaFeatureFlags

private struct RemoteConfigTestError: Error, Equatable {}

private final class MockRemoteConfigBackend: RemoteConfigBackend, @unchecked Sendable {
    var interval: TimeInterval?
    var status = RemoteConfigFetchStatus.fetchedFromRemote
    var fetchError: Error?
    var values: [String: RemoteConfigValueInfo] = [:]
    var keys: [String] = []
    var defaults: [String: NSObject] = [:]

    func configure(minimumFetchInterval: TimeInterval) { interval = minimumFetchInterval }

    func fetchAndActivate() async throws -> RemoteConfigFetchStatus {
        if let fetchError { throw fetchError }
        return status
    }

    func value(forKey key: String) -> RemoteConfigValueInfo {
        values[key] ?? RemoteConfigValueInfo(bool: false, string: "", number: 0, data: Data(), source: .default)
    }

    func remoteKeys() -> [String] { keys }
    func setDefaults(_ defaults: [String: NSObject]) { self.defaults = defaults }
}

struct FirebaseRemoteConfigServiceTests {
    @Test func configuresFetchIntervalOnInit() {
        let backend = MockRemoteConfigBackend()
        _ = FirebaseRemoteConfigService(backend: backend, minimumFetchInterval: 0)
        #expect(backend.interval == 0)
    }

    @Test func fetchSucceedsForEveryStatus() async throws {
        let backend = MockRemoteConfigBackend()
        let service = FirebaseRemoteConfigService(backend: backend)
        for status in [RemoteConfigFetchStatus.fetchedFromRemote, .usingPreFetchedData, .error] {
            backend.status = status
            try await service.fetchAndActivate()
        }
    }

    @Test func fetchRethrowsBackendError() async {
        let backend = MockRemoteConfigBackend()
        backend.fetchError = RemoteConfigTestError()
        await #expect(throws: RemoteConfigTestError.self) { try await FirebaseRemoteConfigService(backend: backend).fetchAndActivate() }
    }

    @Test func describesEveryStatus() {
        #expect(FirebaseRemoteConfigService.describe(.fetchedFromRemote) == "fetchedFromRemote")
        #expect(FirebaseRemoteConfigService.describe(.usingPreFetchedData) == "usingPreFetchedData")
        #expect(FirebaseRemoteConfigService.describe(.error) == "error")
    }

    @Test func resolvedEntriesCoverCatalogueAndUnknownRemoteKeys() {
        let backend = MockRemoteConfigBackend()
        backend.keys = ["zzz_unknown", "aaa_unknown", RemoteConfigCatalog.all[0].key]
        backend.values["aaa_unknown"] = RemoteConfigValueInfo(bool: false, string: "x", number: 0, data: Data(), source: .remote)
        let entries = FirebaseRemoteConfigService(backend: backend).resolvedEntries()
        #expect(entries.count == RemoteConfigCatalog.all.count + 2)
        let unknown = entries.filter { !$0.isInCatalogue }
        #expect(unknown.map(\.key) == ["aaa_unknown", "zzz_unknown"])
        #expect(unknown.first?.value == "x")
    }

    @Test func typedGettersReadBackendValues() {
        let backend = MockRemoteConfigBackend()
        let group = try! JSONEncoder().encode(["enabled": true])
        backend.values["k"] = RemoteConfigValueInfo(bool: true, string: "s", number: 3, data: group, source: .remote)
        let service = FirebaseRemoteConfigService(backend: backend)
        #expect(service.boolValue(forKey: "k"))
        #expect(service.stringValue(forKey: "k") == "s")
        #expect(service.numberValue(forKey: "k") == 3)
        #expect(service.jsonValue(forKey: "k", as: [String: Bool].self)?["enabled"] == true)
        #expect(service.isRemoteValue(forKey: "k"))
        #expect(!service.isRemoteValue(forKey: "other"))
        #expect(service.jsonValue(forKey: "other", as: [String: Bool].self) == nil)
    }

    @Test func setDefaultsBridgesEveryCase() {
        let backend = MockRemoteConfigBackend()
        FirebaseRemoteConfigService(backend: backend).setDefaults([
            "b": .bool(true), "s": .string("x"), "n": .number(2), "j": .json(Data([1]))
        ])
        #expect(backend.defaults["b"] is NSNumber)
        #expect(backend.defaults["s"] as? String == "x")
        #expect((backend.defaults["n"] as? NSNumber)?.doubleValue == 2)
        #expect(backend.defaults["j"] as? Data == Data([1]))
    }
}
