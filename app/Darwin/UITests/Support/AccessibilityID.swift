//
//  AccessibilityID.swift
//  ApoorvaUITests
//
//  Keep raw values in sync with libraries/ApoorvaModules/.../Onboarding/AccessibilityID.swift.
//

enum AccessibilityID {
    enum Splash {
        static let getStarted = "splash.getStarted"
    }

    enum SignInHub {
        static let emailButton = "signInHub.emailButton"
    }

    enum EmailSignIn {
        static let email = "emailSignIn.email"
        static let password = "emailSignIn.password"
        static let signInButton = "emailSignIn.signInButton"
        static let error = "emailSignIn.error"
    }
}

/// Credentials accepted by FakeAuthService (ApoorvaServices).
enum TestCredentials {
    static let email = "uitest@apoorva.app"
    static let password = "UITest@123"
}
