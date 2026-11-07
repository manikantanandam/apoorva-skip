//
//  ApoorvaModulesTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaServices
import ApoorvaModels
import ApoorvaUtilities
@testable import ApoorvaModules

final class MockAuthService: AuthServicing, @unchecked Sendable {
    var loginCalls: [(String, String)] = []
    var logoutCount = 0
    var shouldThrow = false

    struct MockError: Error {}

    var currentUserStream: AsyncStream<AppUser?> {
        AsyncStream { $0.finish() }
    }

    func login(email: String, password: String) async throws {
        loginCalls.append((email, password))
        if shouldThrow { throw MockError() }
    }

    func logout() throws {
        logoutCount += 1
        if shouldThrow { throw MockError() }
    }
}

@MainActor
struct LoginViewModelTests {
    @Test func loginDisabledWhenFieldsEmpty() {
        let vm = LoginViewModel(authService: MockAuthService(), environment: .debug)
        vm.username = ""
        #expect(!vm.isLoginEnabled)
        vm.username = "a@b.com"
        vm.password = ""
        #expect(!vm.isLoginEnabled)
    }

    @Test func loginEnabledWhenFieldsFilled() {
        let vm = LoginViewModel(authService: MockAuthService(), environment: .debug)
        vm.username = "a@b.com"
        vm.password = "pw"
        #expect(vm.isLoginEnabled)
    }

    @Test func loginPressedCallsServiceWithCredentials() async throws {
        let auth = MockAuthService()
        let vm = LoginViewModel(authService: auth, environment: .debug)
        vm.username = "a@b.com"
        vm.password = "pw"
        vm.loginPressed()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(auth.loginCalls.count == 1)
        #expect(auth.loginCalls.first?.0 == "a@b.com")
    }

    @Test func loginPressedSkipsWhenDisabled() async throws {
        let auth = MockAuthService()
        let vm = LoginViewModel(authService: auth, environment: .debug)
        vm.username = ""
        vm.loginPressed()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(auth.loginCalls.isEmpty)
    }

    @Test func loginPressedSwallowsServiceError() async throws {
        let auth = MockAuthService()
        auth.shouldThrow = true
        let vm = LoginViewModel(authService: auth, environment: .debug)
        vm.loginPressed()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(auth.loginCalls.count == 1)
    }
}

@MainActor
struct POSViewModelTests {
    @Test func startsWithQuickItems() {
        let vm = POSViewModel(authService: MockAuthService())
        #expect(!vm.items.isEmpty)
        #expect(vm.customerName.isEmpty)
    }

    @Test func logoutPressedCallsService() {
        let auth = MockAuthService()
        let vm = POSViewModel(authService: auth)
        vm.logoutPressed()
        #expect(auth.logoutCount == 1)
    }

    @Test func logoutPressedSwallowsError() {
        let auth = MockAuthService()
        auth.shouldThrow = true
        let vm = POSViewModel(authService: auth)
        vm.logoutPressed()
        #expect(auth.logoutCount == 1)
    }
}
