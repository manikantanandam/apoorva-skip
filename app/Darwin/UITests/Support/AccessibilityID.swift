//
//  AccessibilityID.swift
//  ApoorvaUITests
//
//  Keep raw values in sync with libraries/ApoorvaModules/.../Onboarding/AccessibilityID.swift.
//

enum AccessibilityID {
    enum Splash {
        static let getStarted = "splash.getStarted"
        static let demo = "splash.demo"
    }

    enum DemoShop {
        static let trySample = "demoShop.trySample"
    }

    enum SignInHub {
        static let emailButton = "signInHub.emailButton"
    }

    enum Pos {
        static let customerRow = "pos.customerRow"
    }

    enum CustomerPicker {
        static let addAndAttach = "customerPicker.addAndAttach"
        static let walkIn = "customerPicker.walkIn"
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
