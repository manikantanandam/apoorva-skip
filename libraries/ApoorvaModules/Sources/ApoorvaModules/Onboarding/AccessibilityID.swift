//
//  AccessibilityID.swift
//  ApoorvaModules
//
//  Identifiers used by UI tests. Keep raw values in sync with app/Darwin/UITests/Support/AccessibilityID.swift.
//

import Foundation

public enum AccessibilityID {
    public enum Splash {
        public static let getStarted = "splash.getStarted"
        public static let demo = "splash.demo"
    }

    public enum DemoShop {
        public static let trySample = "demoShop.trySample"
    }

    public enum SignInHub {
        public static let emailButton = "signInHub.emailButton"
    }

    public enum Pos {
        public static let customerRow = "pos.customerRow"
    }

    public enum CustomerPicker {
        public static let addAndAttach = "customerPicker.addAndAttach"
        public static let walkIn = "customerPicker.walkIn"
    }

    public enum EmailSignIn {
        public static let email = "emailSignIn.email"
        public static let password = "emailSignIn.password"
        public static let signInButton = "emailSignIn.signInButton"
        public static let error = "emailSignIn.error"
    }
}
