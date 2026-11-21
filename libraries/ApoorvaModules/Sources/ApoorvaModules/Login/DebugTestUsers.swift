//
//  DebugTestUsers.swift
//  ApoorvaModules
//

#if DEBUG
import Foundation

/// Debug-only quick-switch accounts for the sign-in screen. Add any number of entries here.
struct DebugTestUser: Identifiable {
    let name: String
    let email: String
    let password: String
    var id: String { email }
}

enum DebugTestUsers {
    static let all: [DebugTestUser] = [
        DebugTestUser(name: "Lavanya", email: "lavanya@gmail.com", password: "Apoorva@125"),
        DebugTestUser(name: "Manikanta", email: "nanirocks125@gmail.com", password: "Nandam@125"),
    ]
}
#endif
