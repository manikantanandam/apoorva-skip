//
//  TextFileSharer.swift
//  ApoorvaModules
//

import SwiftUI

/// Writes text to a file and opens the system share sheet for it. SkipSwiftUI can't share a file (`ShareLink` sends the
/// path as text), so the Android app injects one (see `AndroidTextFileSharer`); iOS uses `ShareSheet` and never reads this.
public struct TextFileSharer: Sendable {
    /// Returns false if the share sheet couldn't be started.
    public var share: @MainActor @Sendable (_ content: String, _ fileName: String, _ mimeType: String) -> Bool

    public init(share: @escaping @MainActor @Sendable (_ content: String, _ fileName: String, _ mimeType: String) -> Bool) {
        self.share = share
    }
}

private struct TextFileSharerKey: EnvironmentKey {
    static let defaultValue: TextFileSharer? = nil
}

public extension EnvironmentValues {
    var textFileSharer: TextFileSharer? {
        get { self[TextFileSharerKey.self] }
        set { self[TextFileSharerKey.self] = newValue }
    }
}
