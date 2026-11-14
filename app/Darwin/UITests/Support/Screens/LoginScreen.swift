//
//  LoginScreen.swift
//  ApoorvaUITests
//
//  Page object for Splash -> Sign-in hub -> Email sign-in.
//

import XCTest

@MainActor
struct LoginScreen {
    let app: XCUIApplication

    var getStartedButton: XCUIElement { app.buttons[AccessibilityID.Splash.getStarted] }
    var emailOptionButton: XCUIElement { app.buttons[AccessibilityID.SignInHub.emailButton] }
    var emailField: XCUIElement { app.textFields[AccessibilityID.EmailSignIn.email] }
    var passwordField: XCUIElement { app.secureTextFields[AccessibilityID.EmailSignIn.password] }
    var signInButton: XCUIElement { app.buttons[AccessibilityID.EmailSignIn.signInButton] }
    var errorNote: XCUIElement { app.staticTexts[AccessibilityID.EmailSignIn.error] }

    /// Splash -> hub -> email sign-in form.
    func openEmailSignIn(timeout: TimeInterval = 10) {
        if getStartedButton.waitForExistence(timeout: timeout) { getStartedButton.tap() }
        XCTAssertTrue(emailOptionButton.waitForExistence(timeout: timeout), "Sign-in hub did not appear")
        emailOptionButton.tap()
        XCTAssertTrue(emailField.waitForExistence(timeout: timeout), "Email sign-in form did not appear")
    }

    func signIn(email: String, password: String) {
        replaceText(in: emailField, with: email)
        replaceText(in: passwordField, with: password)
        signInButton.tap()
    }

    /// Debug builds prefill the form, so clear existing text before typing.
    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        if let current = field.value as? String, !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text)
    }
}
