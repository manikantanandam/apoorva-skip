import Foundation

enum OnboardingRoute: Hashable, Identifiable {
    case splash
    case signInHub
    case otp(phone: String)
    case emailSignIn
    case register
    case verifyEmail
    case forgotPassword
    case googleChooser
    case linkAccounts(email: String)
    case chooseVertical
    case shopSetup
    case pickLook
    case firstRunGuide
    case openingBalances
    case pinSwitch

    var id: Self { self }
}
