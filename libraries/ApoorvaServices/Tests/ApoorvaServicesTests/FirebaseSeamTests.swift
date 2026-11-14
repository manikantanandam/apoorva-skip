//
//  FirebaseSeamTests.swift
//  ApoorvaServices
//

import Testing
import Foundation
import FirebaseAuth
import FirebaseFirestore
import ApoorvaModels
@testable import ApoorvaServices

// MARK: - Auth

private final class MockAuthBackend: AuthBackend, @unchecked Sendable {
    var currentUser: AuthUserInfo?
    var error: Error?
    var calls: [String] = []
    var handler: (@Sendable (AuthUserInfo?) -> Void)?
    var removeCount = 0

    private func record(_ call: String) throws {
        calls.append(call)
        if let error { throw error }
    }

    func signIn(email: String, password: String) async throws { try record("signIn") }
    func signOut() throws { try record("signOut") }
    func createUser(name: String, email: String, password: String) async throws { try record("createUser") }
    func sendEmailVerification() async throws { try record("sendEmailVerification") }
    func reloadUser() async throws { try record("reloadUser") }
    func sendPasswordReset(email: String) async throws { try record("sendPasswordReset") }
    func link(email: String, password: String) async throws { try record("link") }
    func updatePassword(_ password: String) async throws { try record("updatePassword") }

    func observe(_ handler: @escaping @Sendable (AuthUserInfo?) -> Void) -> @Sendable () -> Void {
        self.handler = handler
        handler(currentUser)
        return { [weak self] in self?.removeCount += 1 }
    }
}

private func userInfo(providers: [String] = ["password"], verified: Bool = false) -> AuthUserInfo {
    AuthUserInfo(uid: "u1", email: "u@u.com", displayName: "U", isEmailVerified: verified, providerIDs: providers)
}

struct AuthServiceTests {
    @Test func loginRegisterAndResetDelegateToBackend() async throws {
        let backend = MockAuthBackend()
        let service = AuthService(backend: backend)
        try await service.login(email: "e", password: "p")
        try await service.register(name: "n", email: "e", password: "p")
        try await service.sendPasswordReset(email: "e")
        try service.logout()
        #expect(backend.calls == ["signIn", "createUser", "sendPasswordReset", "signOut"])
    }

    @Test func backendErrorsAreMapped() async {
        let backend = MockAuthBackend()
        backend.error = NSError(domain: AuthErrorDomain, code: AuthErrorCode.wrongPassword.rawValue)
        backend.currentUser = userInfo()
        let service = AuthService(backend: backend)
        let expected = AuthServiceError.message("Email or password is incorrect.")
        await #expect(throws: expected) { try await service.login(email: "e", password: "p") }
        await #expect(throws: expected) { try await service.register(name: "n", email: "e", password: "p") }
        await #expect(throws: expected) { try await service.sendPasswordReset(email: "e") }
        await #expect(throws: expected) { try await service.linkEmail(email: "e", password: "p") }
    }

    @Test func logoutPropagatesBackendError() {
        let backend = MockAuthBackend()
        backend.error = AuthServiceError.unsupported
        #expect(throws: AuthServiceError.self) { try AuthService(backend: backend).logout() }
    }

    @Test func signedOutActionsThrowNotSignedIn() async throws {
        let service = AuthService(backend: MockAuthBackend())
        await #expect(throws: AuthServiceError.notSignedIn) { try await service.sendEmailVerification() }
        await #expect(throws: AuthServiceError.notSignedIn) { try await service.linkEmail(email: "e", password: "p") }
        await #expect(throws: AuthServiceError.notSignedIn) { try await service.updatePassword("p") }
        #expect(try await service.reloadAccount() == nil)
        #expect(service.currentAccount == nil)
        #expect(service.linkedProviders().isEmpty)
    }

    @Test func signedInActionsDelegateToBackend() async throws {
        let backend = MockAuthBackend()
        backend.currentUser = userInfo(verified: true)
        let service = AuthService(backend: backend)
        try await service.sendEmailVerification()
        try await service.linkEmail(email: "e", password: "p")
        try await service.updatePassword("p")
        #expect(backend.calls == ["sendEmailVerification", "link", "updatePassword"])
        #expect(try await service.reloadAccount()?.uid == "u1")
        #expect(service.currentAccount?.isEmailVerified == true)
        #expect(service.linkedProviders() == ["password"])
    }

    @Test func accountVerificationRules() {
        #expect(AuthService.account(from: nil) == nil)
        #expect(AuthService.account(from: userInfo(providers: ["password"], verified: false))?.isEmailVerified == false)
        #expect(AuthService.account(from: userInfo(providers: ["password"], verified: true))?.isEmailVerified == true)
        #expect(AuthService.account(from: userInfo(providers: ["google.com"], verified: false))?.isEmailVerified == true)
    }

    @Test func mapsEveryKnownErrorCode() {
        let cases: [(AuthErrorCode, String?)] = [
            (.emailAlreadyInUse, "An account with this email already exists. Sign in instead."),
            (.invalidCredential, "Email or password is incorrect."),
            (.userNotFound, "No account found for this email."),
            (.weakPassword, "Use at least 6 characters for your password."),
            (.invalidEmail, "Enter a valid email address."),
            (.networkError, "No internet connection. Try again when you're online."),
            (.tooManyRequests, "Too many attempts. Wait a minute and try again.")
        ]
        for (code, message) in cases {
            let error = NSError(domain: AuthErrorDomain, code: code.rawValue)
            #expect(AuthService.mapped(error, email: "e") as? AuthServiceError == .message(message ?? ""))
        }
        for code in [AuthErrorCode.accountExistsWithDifferentCredential, .credentialAlreadyInUse] {
            let error = NSError(domain: AuthErrorDomain, code: code.rawValue)
            #expect(AuthService.mapped(error, email: "e") as? AuthServiceError == .accountExistsWithDifferentCredential(email: "e"))
        }
    }

    @Test func unknownErrorsPassThrough() {
        let error = NSError(domain: "other", code: 1)
        #expect((AuthService.mapped(error, email: "e") as NSError) === error)
    }

    @Test func accountStreamEmitsAndRemovesListener() async {
        let backend = MockAuthBackend()
        backend.currentUser = userInfo(verified: true)
        let service = AuthService(backend: backend)
        for await account in service.accountStream {
            #expect(account?.uid == "u1")
            break
        }
        backend.handler?(nil)
        #expect(backend.removeCount == 1)
    }

    @Test func currentUserStreamMapsUserAndSignOut() async {
        let backend = MockAuthBackend()
        backend.currentUser = AuthUserInfo(uid: "u1", email: nil, displayName: nil, isEmailVerified: false, providerIDs: [])
        let service = AuthService(backend: backend)
        var iterator = service.currentUserStream.makeAsyncIterator()
        let signedIn = await iterator.next()
        #expect(signedIn??.id == "u1")
        #expect(signedIn??.name == "")
        #expect(signedIn??.email == "")
        backend.handler?(nil)
        let signedOut = await iterator.next()
        #expect(signedOut != nil && signedOut! == nil)
    }
}

// MARK: - Analytics / Crashlytics / Performance

private final class RecordingAnalyticsBackend: AnalyticsBackend, @unchecked Sendable {
    var events: [(name: String, parameters: [String: Any]?)] = []
    var properties: [(String?, String)] = []
    var userIds: [String?] = []
    var enabled: [Bool] = []

    func logEvent(_ name: String, parameters: [String: Any]?) { events.append((name, parameters)) }
    func setUserProperty(_ value: String?, forName name: String) { properties.append((value, name)) }
    func setUserID(_ id: String?) { userIds.append(id) }
    func setCollectionEnabled(_ enabled: Bool) { self.enabled.append(enabled) }
}

struct FirebaseAnalyticsServiceTests {
    @Test func mapsEveryParameterType() {
        let backend = RecordingAnalyticsBackend()
        let service = FirebaseAnalyticsService(backend: backend)
        service.log(AnalyticsEvent(name: "e", parameters: ["s": .string("a"), "i": .int(1), "d": .double(1.5), "b": .bool(true)]))
        let parameters = backend.events.first?.parameters
        #expect(parameters?["s"] as? String == "a")
        #expect(parameters?["i"] as? Int == 1)
        #expect(parameters?["d"] as? Double == 1.5)
        #expect(parameters?["b"] as? Bool == true)
    }

    @Test func emptyParametersBecomeNil() {
        let backend = RecordingAnalyticsBackend()
        FirebaseAnalyticsService(backend: backend).log(AnalyticsEvent(name: "e"))
        #expect(backend.events.first?.name == "e")
        #expect(backend.events.first?.parameters == nil)
    }

    @Test func forwardsUserAndCollectionSettings() {
        let backend = RecordingAnalyticsBackend()
        let service = FirebaseAnalyticsService(backend: backend)
        service.setUserProperty("v", forName: "n")
        service.setUserId("u")
        service.setAnalyticsCollectionEnabled(true)
        #expect(backend.properties.first?.1 == "n")
        #expect(backend.userIds == ["u"])
        #expect(backend.enabled == [true])
    }
}

private final class RecordingCrashBackend: CrashlyticsBackend, @unchecked Sendable {
    var calls: [String] = []
    func record(_ error: Error) { calls.append("record") }
    func setCustomValue(_ value: String, forKey key: String) { calls.append("\(key)=\(value)") }
    func setUserID(_ id: String) { calls.append("user:\(id)") }
    func log(_ message: String) { calls.append("log:\(message)") }
}

struct FirebaseCrashReportingServiceTests {
    @Test func recordNonFatalSetsContextThenRecords() {
        let backend = RecordingCrashBackend()
        FirebaseCrashReportingService(backend: backend).recordNonFatal(AuthServiceError.unsupported, context: "ctx")
        #expect(backend.calls == ["lastErrorContext=ctx", "record"])
    }

    @Test func forwardsKeysUsersAndLogs() {
        let backend = RecordingCrashBackend()
        let service = FirebaseCrashReportingService(backend: backend)
        service.setCustomKey("v", forKey: "k")
        service.setUserId(nil)
        service.setUserId("u")
        service.log("m")
        #expect(backend.calls == ["k=v", "user:", "user:u", "log:m"])
    }
}

private final class RecordingTraceBackend: PerformanceTraceBackend, @unchecked Sendable {
    var started: [String] = []
    var stopped = 0
    var returnsTrace = true

    func startTrace(_ name: String) -> (@Sendable () -> Void)? {
        started.append(name)
        guard returnsTrace else { return nil }
        return { [weak self] in self?.stopped += 1 }
    }
}

struct FirebasePerformanceMonitoringServiceTests {
    @Test func stopsTraceAfterOperation() async {
        let backend = RecordingTraceBackend()
        let result = await FirebasePerformanceMonitoringService(backend: backend).measure("t") { 7 }
        #expect(result == 7)
        #expect(backend.started == ["t"] && backend.stopped == 1)
    }

    @Test func stopsTraceWhenOperationThrows() async {
        let backend = RecordingTraceBackend()
        await #expect(throws: AuthServiceError.self) {
            try await FirebasePerformanceMonitoringService(backend: backend).measure("t") { throw AuthServiceError.unsupported }
        }
        #expect(backend.stopped == 1)
    }

    @Test func runsOperationWhenNoTraceIsCreated() async {
        let backend = RecordingTraceBackend()
        backend.returnsTrace = false
        let result = await FirebasePerformanceMonitoringService(backend: backend).measure("t") { 1 }
        #expect(result == 1 && backend.stopped == 0)
    }
}

// MARK: - Remote config

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
        backend.fetchError = AuthServiceError.unsupported
        await #expect(throws: AuthServiceError.self) { try await FirebaseRemoteConfigService(backend: backend).fetchAndActivate() }
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
        let gate = try! JSONEncoder().encode(VersionGateValue(enabled: true, minVersion: "2.0.0"))
        backend.values["k"] = RemoteConfigValueInfo(bool: true, string: "s", number: 3, data: gate, source: .remote)
        let service = FirebaseRemoteConfigService(backend: backend)
        #expect(service.boolValue(forKey: "k"))
        #expect(service.stringValue(forKey: "k") == "s")
        #expect(service.numberValue(forKey: "k") == 3)
        #expect(service.jsonValue(forKey: "k", as: VersionGateValue.self)?.minVersion == "2.0.0")
        #expect(service.isRemoteValue(forKey: "k"))
        #expect(!service.isRemoteValue(forKey: "other"))
        #expect(service.jsonValue(forKey: "other", as: VersionGateValue.self) == nil)
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

// MARK: - Firestore store pure helpers

struct FirebaseFirestoreStoreHelperTests {
    @Test func buildsOneFilterPerCondition() {
        let query = StoreQuery(conditions: [
            .greaterThan(field: "a", date: epoch(1)),
            .isIn(field: "b", values: ["x"]),
            .arrayContains(field: "c", value: "y")
        ])
        #expect(FirebaseFirestoreStore.filters(for: query).count == 3)
        #expect(FirebaseFirestoreStore.filters(for: .all).isEmpty)
    }

    @Test func resolvesOnlyTheServerTimestampSentinel() {
        let resolved = FirebaseFirestoreStore.resolvingSentinels([
            "stamp": StoreSentinel.serverTimestamp, "name": "plain", "count": 3
        ])
        #expect(resolved["stamp"] is FieldValue)
        #expect(resolved["name"] as? String == "plain")
        #expect(resolved["count"] as? Int == 3)
    }
}
