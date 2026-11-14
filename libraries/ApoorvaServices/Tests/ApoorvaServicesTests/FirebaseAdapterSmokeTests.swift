//
//  FirebaseAdapterSmokeTests.swift
//  ApoorvaServices
//
//  Runs the thin `Firebase*Backend` adapters against a configured-but-fake Firebase app so
//  their SDK calls execute. Nothing here asserts server behaviour: Auth points at an
//  unreachable emulator, Firestore runs offline, and calls that wait on a server are
//  started without being awaited.
//

import Testing
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
@testable import ApoorvaServices

private let configureFirebase: Void = {
    if FirebaseApp.app() == nil {
        let options = FirebaseOptions(googleAppID: "1:1234567890:ios:0123456789abcdef", gcmSenderID: "1234567890")
        // Firebase Installations validates the format: 39 characters, starting with "A".
        options.apiKey = "AIzaSy000000000000000000000000000000000"
        options.projectID = "fake-project"
        FirebaseApp.configure(options: options)
    }
    Auth.auth().useEmulator(withHost: "127.0.0.1", port: 1)
}()

@Suite(.serialized)
struct FirebaseAdapterSmokeTests {

    @Test func observabilityAdaptersForwardToSDK() {
        _ = configureFirebase
        let analytics = FirebaseAnalyticsService()
        analytics.log(AnalyticsEvent(name: "smoke", parameters: ["k": .string("v")]))
        analytics.setUserProperty("v", forName: "n")
        analytics.setUserId("u")
        analytics.setAnalyticsCollectionEnabled(false)

        let crash = FirebaseCrashReportingService()
        crash.recordNonFatal(AuthServiceError.unsupported, context: "smoke")
        crash.setCustomKey("v", forKey: "k")
        crash.setUserId(nil)
        crash.log("smoke")

        let stop = FirebasePerformanceBackend().startTrace("smoke")
        stop?()
    }

    @Test func performanceServiceMeasuresThroughSDK() async {
        _ = configureFirebase
        #expect(await FirebasePerformanceMonitoringService().measure("smoke") { 1 } == 1)
    }

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

    @Test func authAdapterWithNoUser() async throws {
        _ = configureFirebase
        let backend = FirebaseAuthBackend()
        #expect(backend.currentUser == nil)
        try await backend.sendEmailVerification()
        try await backend.reloadUser()
        try await backend.link(email: "a@b.co", password: "secret1")
        try await backend.updatePassword("secret1")

        let remove = backend.observe { _ in }
        remove()
        try? backend.signOut()

        // These reach the unreachable emulator; don't wait for them.
        Task { try? await backend.signIn(email: "a@b.co", password: "secret1") }
        Task { try? await backend.createUser(name: "n", email: "a@b.co", password: "secret1") }
        Task { try? await backend.sendPasswordReset(email: "a@b.co") }
        try await Task.sleep(for: .milliseconds(300))
    }

    @Test func authServiceDefaultInitUsesFirebase() {
        _ = configureFirebase
        let service = AuthService()
        #expect(service.currentAccount == nil)
        #expect(service.linkedProviders().isEmpty)
    }

    @Test func firestoreStoreRunsAgainstLocalCache() async throws {
        _ = configureFirebase
        try await Firestore.firestore().disableNetwork()
        let store = FirebaseFirestoreStore()
        let id = UUID().uuidString
        try store.setData(["name": "smoke", "stamp": StoreSentinel.serverTimestamp, "tags": ["a"]], path: "smoke/\(id)", merge: false)

        let document = try await store.getDocument(path: "smoke/\(id)")
        #expect(document?.id == id)
        // A document that was never cached errors while offline; only the call matters here.
        _ = try? await store.getDocument(path: "smoke/missing-\(id)")

        let conditions: [StoreCondition] = [
            .greaterThan(field: "when", date: Date(timeIntervalSince1970: 0)),
            .isIn(field: "name", values: ["smoke"]),
            .arrayContains(field: "tags", value: "a")
        ]
        _ = try await store.getDocuments(collection: "smoke", query: .all)
        _ = try await store.getDocuments(collection: "smoke", query: StoreQuery(conditions: [conditions[1]]))
        _ = try await store.getDocuments(collection: "smoke", query: StoreQuery(conditions: [conditions[1], conditions[2]], matchAny: true))

        for await value in store.listen(path: "smoke/\(id)") {
            #expect(value?.id == id)
            break
        }
        for await value in store.listen(path: "smoke/missing-\(id)") {
            #expect(value == nil)
            break
        }

        // Waits for a server acknowledgement, so start it without awaiting.
        Task { try? await store.updateData(["name": "changed"], path: "smoke/\(id)") }
        try await Task.sleep(for: .milliseconds(200))
    }
}
