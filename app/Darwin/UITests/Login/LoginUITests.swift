//
//  LoginUITests.swift
//  ApoorvaUITests
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

    func testLoginWithValidCredentialsLeavesSignInScreen() {
        login.signIn(email: TestCredentials.email, password: TestCredentials.password)

        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: login.signInButton)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(login.errorNote.exists)
    }

    func testLoginWithWrongPasswordShowsError() {
        login.signIn(email: TestCredentials.email, password: "wrong-password")

        XCTAssertTrue(login.errorNote.waitForExistence(timeout: 10))
        XCTAssertTrue(login.signInButton.exists)
    }
}
