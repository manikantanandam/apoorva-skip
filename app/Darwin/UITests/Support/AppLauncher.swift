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

    /// Launches signed in to a seeded sample shop (`fancy` or `kirana`), landing on Home.
    /// Mirrors `UITestingConfig.seedLaunchArgument`; the seed is DEBUG-only.
    @MainActor
    static func launchSeeded(vertical: String = "fancy") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting", "-UITestingSeed", vertical]
        app.launch()
        return app
    }
}
