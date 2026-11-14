//
//  AppLauncher.swift
//  ApoorvaUITests
//

import XCTest

enum AppLauncher {
    /// Launches the app in UI-testing mode (fake auth, no Firebase, clean state).
    @MainActor
    static func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting"]
        app.launch()
        return app
    }
}
