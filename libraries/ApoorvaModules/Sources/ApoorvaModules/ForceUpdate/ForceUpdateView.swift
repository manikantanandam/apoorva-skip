//
//  ForceUpdateView.swift
//  ApoorvaModules
//

import SwiftUI

/// Blocking screen shown when the installed app is older than the `min_app_version` flag.
public struct ForceUpdateView: View {
    let requiredVersion: String
    let currentVersion: String
    /// Debug builds only: lets developers reach Developer settings to change the override or fetch again.
    let onOpenDeveloper: (() -> Void)?

    public init(requiredVersion: String, currentVersion: String, onOpenDeveloper: (() -> Void)? = nil) {
        self.requiredVersion = requiredVersion
        self.currentVersion = currentVersion
        self.onOpenDeveloper = onOpenDeveloper
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.app")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Update required")
                .font(.title2.bold())
            Text("This version of Apoorva is no longer supported. Please update the app to continue.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                Text("Installed: \(currentVersion)")
                Text("Required: \(requiredVersion)")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            if let onOpenDeveloper {
                Button("Developer settings", action: onOpenDeveloper)
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
