//
//  UserFacingError.swift
//  ApoorvaModules
//

import Foundation

/// Text to show the user for an error.
enum UserFacingError {
    static func message(for error: Error) -> String {
        #if os(Android)
        // Java exceptions (e.g. Firebase Auth) arrive as `SwiftJNI.ThrowableError`, whose `localizedDescription`
        // is only "The operation could not be completed. (SwiftJNI.ThrowableError error 1.)". Its description
        // carries the Java `toString()`, "<exception class>: <message>"; show the message part.
        let description = String(describing: error)
        if let range = description.range(of: "Exception: ") {
            return String(description[range.upperBound...])
        }
        #endif
        return error.localizedDescription
    }
}
