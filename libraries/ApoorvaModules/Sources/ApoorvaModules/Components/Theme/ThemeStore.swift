import ManiSwiftUIComponents
import SwiftUI
import ApoorvaModels

/// Owns the app's resolved theme (accent + Clean/Bold + light/dark) and the signed-in member's
/// own appearance preference. Resolution order lives in `ThemeResolver` (docs/04).
@MainActor
@Observable
public final class ThemeStore {
    public private(set) var theme: any ManiTheme
    public private(set) var style: ManiStyle
    public private(set) var resolved: ResolvedTheme
    public private(set) var preference: UserThemePreference

    private let defaults: UserDefaults
    private var userId: String?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let preference = Self.loadPreference(from: defaults, for: nil)
        let resolved = ThemeResolver.resolve(org: nil, store: nil, user: preference, vertical: nil)
        self.preference = preference
        self.resolved = resolved
        self.theme = Self.maniTheme(for: resolved.accent, style: resolved.style)
        self.style = resolved.style == .bold ? .bold : .clean
    }

    /// SwiftUI colour scheme override, nil to follow the system.
    public var colorScheme: ColorScheme? {
        switch resolved.scheme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Re-resolves from the current session. Cheap; call on any session/settings change.
    public func apply(session: AppSession?) {
        let uid = session?.user?.id
        if uid != userId {
            userId = uid
            preference = loadPreference(for: uid)
        }
        let orgTheme = (session?.hasSettingsDoc ?? false) ? session?.settings.theme : nil
        resolved = ThemeResolver.resolve(org: orgTheme,
                                         store: session?.stores.isEmpty == false ? session?.currentStore : nil,
                                         user: preference,
                                         vertical: session?.vertical,
                                         appDefaultStyle: session?.platform.defaultVisualStyle ?? .clean)
        theme = Self.maniTheme(for: resolved.accent, style: resolved.style)
        style = resolved.style == .bold ? .bold : .clean
    }

    public func updatePreference(_ update: (inout UserThemePreference) -> Void, session: AppSession?) {
        update(&preference)
        savePreference(preference, for: userId)
        apply(session: session)
    }

    /// Previews a look without saving (onboarding "Pick a look").
    public func preview(accent: AccentKey, style visualStyle: OrgSettings.VisualStyle, scheme: ColorSchemePreference) {
        resolved = ResolvedTheme(accent: accent, style: visualStyle, font: resolved.font, scheme: scheme, isLockedByOrg: false)
        theme = Self.maniTheme(for: accent, style: visualStyle)
        style = visualStyle == .bold ? .bold : .clean
    }

    public static func maniTheme(for accent: AccentKey, style: OrgSettings.VisualStyle) -> ManiAccentTheme {
        switch (accent, style) {
        case (.ink, .clean): .apoorvaInk
        case (.ink, .bold): .boldIndigo
        case (.sage, .clean): .kiranaSage
        case (.sage, .bold): .boldTeal
        case (.plum, .clean): .fancyPlum
        case (.plum, .bold): .boldOrchid
        case (.brass, .clean): .jewelleryBrass
        case (.brass, .bold): .boldGold
        case (.rose, .clean): .parlourRose
        case (.rose, .bold): .boldRose
        case (.slate, _):
            ManiAccentTheme(name: "Slate",
                            lightAccent: ManiAccentColors(accent: Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255), on: .white),
                            darkAccent: ManiAccentColors(accent: Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255),
                                                         on: Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)))
        }
    }

    /// Swatch colour shown in pickers for each accent.
    public static func swatchColor(for accent: AccentKey) -> Color {
        maniTheme(for: accent, style: .clean).accentColors(for: .light).accent
    }

    private func loadPreference(for uid: String?) -> UserThemePreference {
        Self.loadPreference(from: defaults, for: uid)
    }

    private static func loadPreference(from defaults: UserDefaults, for uid: String?) -> UserThemePreference {
        guard let data = defaults.data(forKey: key(for: uid)),
              let decoded = try? JSONDecoder().decode(UserThemePreference.self, from: data) else {
            return UserThemePreference()
        }
        return decoded
    }

    private func savePreference(_ preference: UserThemePreference, for uid: String?) {
        if let data = try? JSONEncoder().encode(preference) {
            defaults.set(data, forKey: Self.key(for: uid))
        }
    }

    private static func key(for uid: String?) -> String { "apoorva.theme.\(uid ?? "guest")" }
}

public extension View {
    /// Applies a `ThemeStore`'s current resolution at the app root.
    func maniTheme(from store: ThemeStore) -> some View {
        maniThemeErased(store.theme, style: store.style)
            .preferredColorScheme(store.colorScheme)
            .tint(store.theme.accentColors(for: .light).accent)
    }
}
