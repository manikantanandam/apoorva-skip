//
//  File.swift
//  ApoorvaServices
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation
import ApoorvaModels
import FirebaseAuth

struct SendableAuthHandle: @unchecked Sendable {
    let value: AuthStateDidChangeListenerHandle
}

public protocol AuthServicing: Sendable {
    
    var currentUserStream: AsyncStream<AppUser?> { get }
    
    func login(email: String, password: String) async throws
    
    func logout() throws
}

final public class AuthService: AuthServicing {
    
    public init() {
        
    }
    
    public func login(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    public func logout() throws {
        try Auth.auth().signOut()
    }
    
    // Exposes Firebase state as a modern Swift AsyncStream
    public var currentUserStream: AsyncStream<AppUser?> {
        AsyncStream { continuation in
            // Firebase triggers this immediately on attach, and on any future changes
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                guard let user else {
                    continuation.yield(nil)
                    return
                }
                
                let appUser = AppUser(id: user.uid, name: "", email: "", role: .standard, status: "", assignedOrgs: [], createdAt: Date(), updatedAt: Date())
                continuation.yield(appUser)
            }
            
            let sendableHandle = SendableAuthHandle(value: handle)
            
            // Automatically unregister the Firebase listener when the Task cancels
            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(sendableHandle.value)
            }
        }
    }
    
    public func logOut() throws {
        try Auth.auth().signOut()
    }
    
}
