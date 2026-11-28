//
//  DebugTestUsers.swift
//  ApoorvaModules
//

#if DEBUG
import Foundation

/// Debug-only quick-switch accounts for the sign-in screen. The first one prefills the sign-in form in the
/// debug environment. Sourced from environment variables (set once in your Xcode scheme's "Arguments" tab)
/// instead of literals, so no real credentials are committed: APOORVA_DEBUG_USER<n>_EMAIL / _PASSWORD /
/// _NAME (optional, defaults to the email) for n = 1, 2, ...
struct DebugTestUser: Identifiable {
    let name: String
    let email: String
    let password: String
    var id: String { email }
}

enum DebugTestUsers {
    static let all: [DebugTestUser] = {
        let environment = ProcessInfo.processInfo.environment
        var users: [DebugTestUser] = []
        var index = 1
        while let email = environment["APOORVA_DEBUG_USER\(index)_EMAIL"],
              let password = environment["APOORVA_DEBUG_USER\(index)_PASSWORD"] {
            let name = environment["APOORVA_DEBUG_USER\(index)_NAME"] ?? email
            users.append(DebugTestUser(name: name, email: email, password: password))
            index += 1
        }
        return users
    }()
}
#endif
