import Foundation

enum OnboardingRoute: Hashable, Identifiable {
    case splash
    case demoShop
    case signInHub
    case emailSignIn
    case register
    case verifyEmail
    case forgotPassword
    case googleChooser
    case linkAccounts
    case chooseVertical
    case shopSetup
    case pickLook
    case firstRunGuide
    case openingBalances
    case staffJoin(inviteToken: String)
    case pinSwitch

    var id: Self { self }
}
