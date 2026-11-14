//
//  ThemeResolverExtraTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("ThemeResolver Extra Tests")
struct ThemeResolverExtraTests {

    @Test("Scheme titles")
    func schemeTitles() {
        #expect(ColorSchemePreference.system.title == "System")
        #expect(ColorSchemePreference.light.title == "Light")
        #expect(ColorSchemePreference.dark.title == "Dark")
    }

    @Test("User preference defaults")
    func userDefaults() {
        let pref = UserThemePreference()
        #expect(pref.accent == nil)
        #expect(pref.style == nil)
        #expect(pref.scheme == .system)
        #expect(pref.useOrgTheme)
        #expect(!pref.largerText)
        #expect(!pref.compactLists)
    }

    @Test("Without any context the accent is ink and style is the app default")
    func noContext() {
        let theme = ThemeResolver.resolve(org: nil, store: nil, user: UserThemePreference(), vertical: nil)
        #expect(theme.accent == .ink)
        #expect(theme.style == .clean)
        #expect(theme.font == "System")
        #expect(!theme.isLockedByOrg)
        let bold = ThemeResolver.resolve(org: nil, store: nil, user: UserThemePreference(), vertical: nil, appDefaultStyle: .bold)
        #expect(bold.style == .bold)
    }

    @Test("Locked theme falls back to store accent, then vertical accent")
    func lockedFallbacks() {
        let org = OrgSettings.Theme(accent: nil, style: .bold, font: "Serif", locked: true)
        var store = Store(id: "s", name: "S", vertical: .fancy)

        let verticalOnly = ThemeResolver.resolve(org: org, store: store, user: UserThemePreference(), vertical: nil)
        #expect(verticalOnly.accent == .plum)
        #expect(verticalOnly.font == "Serif")
        #expect(verticalOnly.style == .bold)

        store.accent = .slate
        let withStore = ThemeResolver.resolve(org: org, store: store, user: UserThemePreference(), vertical: nil)
        #expect(withStore.accent == .slate)
    }

    @Test("User opting into org theme ignores their own accent and style")
    func useOrgTheme() {
        let user = UserThemePreference(accent: .rose, style: .bold, useOrgTheme: true)
        let org = OrgSettings.Theme(accent: .brass, style: .clean)
        let theme = ThemeResolver.resolve(org: org, store: nil, user: user, vertical: nil)
        #expect(theme.accent == .brass)
        #expect(theme.style == .clean)
    }

    @Test("Resolved themes compare by value")
    func equality() {
        let a = ResolvedTheme(accent: .ink, style: .clean, font: "System", scheme: .light, isLockedByOrg: false)
        let b = ResolvedTheme(accent: .ink, style: .clean, font: "System", scheme: .light, isLockedByOrg: false)
        let c = ResolvedTheme(accent: .rose, style: .clean, font: "System", scheme: .light, isLockedByOrg: false)
        #expect(a == b)
        #expect(a != c)
    }
}
