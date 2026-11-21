//
//  LoginUITests.swift
//  ApoorvaUITests
//
//  The whole screen is one test so the app launches once. The wrong-password scenario runs first because a
//  successful sign-in leaves the screen.
//

import XCTest

@MainActor
final class LoginUITests: XCTestCase {
    private var app: XCUIApplication!
    private var login: LoginScreen!

    override func setUp() async throws {
        continueAfterFailure = false
        app = AppLauncher.launch()
        login = LoginScreen(app: app)
        login.openEmailSignIn()
    }

    func testLogin() {
        XCTContext.runActivity(named: "Wrong password shows error") { _ in
            login.signIn(email: TestCredentials.email, password: "wrong-password")

            XCTAssertTrue(login.errorNote.waitForExistence(timeout: 10))
            XCTAssertTrue(login.signInButton.exists)
        }

        XCTContext.runActivity(named: "Valid credentials leave sign-in screen") { _ in
            login.signIn(email: TestCredentials.email, password: TestCredentials.password)

            let gone = NSPredicate(format: "exists == false")
            expectation(for: gone, evaluatedWith: login.signInButton)
            waitForExpectations(timeout: 10)
            XCTAssertFalse(login.errorNote.exists)
        }
    }
}
