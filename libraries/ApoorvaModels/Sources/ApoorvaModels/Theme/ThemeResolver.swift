//
//  ThemeResolver.swift
//  ApoorvaModels
//

import Foundation

public enum ColorSchemePreference: String, Codable, Sendable, CaseIterable {
    case system, light, dark

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// A member's own appearance choices, stored per user on the device.
public struct UserThemePreference: Codable, Sendable, Hashable {
    public var accent: AccentKey?
    public var style: OrgSettings.VisualStyle?
    public var scheme: ColorSchemePreference
    public var useOrgTheme: Bool
    public var largerText: Bool
    public var compactLists: Bool

    public init(accent: AccentKey? = nil, style: OrgSettings.VisualStyle? = nil, scheme: ColorSchemePreference = .system,
                useOrgTheme: Bool = true, largerText: Bool = false, compactLists: Bool = false) {
        self.accent = accent
        self.style = style
        self.scheme = scheme
        self.useOrgTheme = useOrgTheme
        self.largerText = largerText
        self.compactLists = compactLists
    }
}

public struct ResolvedTheme: Sendable, Equatable {
    public let accent: AccentKey
    public let style: OrgSettings.VisualStyle
    public let font: String
    public let scheme: ColorSchemePreference
    public let isLockedByOrg: Bool

    public init(accent: AccentKey, style: OrgSettings.VisualStyle, font: String, scheme: ColorSchemePreference, isLockedByOrg: Bool) {
        self.accent = accent
        self.style = style
        self.font = font
        self.scheme = scheme
        self.isLockedByOrg = isLockedByOrg
    }
}

/// docs/04 theme resolution, first match wins: org lock → user → store → org → vertical default.
/// Light/dark stays the user's choice even when the theme is locked (unless the org disables dark).
public enum ThemeResolver {
    public static func resolve(org: OrgSettings.Theme?,
                               store: Store?,
                               user: UserThemePreference,
                               vertical: Vertical?,
                               appDefaultStyle: OrgSettings.VisualStyle = .clean) -> ResolvedTheme {
        let verticalAccent = (store?.vertical ?? vertical)?.defaultAccent ?? .ink
        let orgStyle = org?.style ?? appDefaultStyle
        let locked = org?.locked ?? false
        let scheme: ColorSchemePreference = (org?.allowDark ?? true) ? user.scheme : .light

        if locked {
            return ResolvedTheme(accent: org?.accent ?? store?.accent ?? verticalAccent,
                                 style: orgStyle,
                                 font: org?.font ?? "System",
                                 scheme: scheme,
                                 isLockedByOrg: true)
        }

        let userAccent = user.useOrgTheme ? nil : user.accent
        let userStyle = user.useOrgTheme ? nil : user.style
        return ResolvedTheme(accent: userAccent ?? store?.accent ?? org?.accent ?? verticalAccent,
                             style: userStyle ?? orgStyle,
                             font: org?.font ?? "System",
                             scheme: scheme,
                             isLockedByOrg: false)
    }
}
