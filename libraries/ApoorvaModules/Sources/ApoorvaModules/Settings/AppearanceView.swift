//
//  AppearanceView.swift
//  ApoorvaModules
//

import SwiftUI
import ManiSwiftUIComponents
import ApoorvaModels

/// Design 97: Light / Dark / System, accent swatches, "Use organisation theme" (locked when the
/// org locks its theme), larger text, compact lists. Changes apply immediately.
public struct AppearanceView: View {
    private let session: AppSession
    @Bindable private var themeStore: ThemeStore

    public init(session: AppSession, themeStore: ThemeStore) {
        self.session = session
        self.themeStore = themeStore
    }

    private var isLocked: Bool { themeStore.resolved.isLockedByOrg }

    public var body: some View {
        ScreenScroll {
            SectionHeader(title: "Mode")
            ManiSegmentedControl(
                selection: Binding(
                    get: { themeStore.preference.scheme },
                    set: { value in themeStore.updatePreference({ $0.scheme = value }, session: session) }
                ),
                options: ColorSchemePreference.allCases.map { (value: $0, title: $0.title) }
            )
            .disabled(!session.settings.theme.allowDark)

            SectionHeader(title: "Accent colour")
            ManiSwatchRow(
                options: AccentKey.allCases.map { (value: $0, title: $0.title, color: ThemeStore.swatchColor(for: $0)) },
                selection: Binding(
                    get: { themeStore.resolved.accent },
                    set: { value in
                        themeStore.updatePreference({ $0.accent = value; $0.useOrgTheme = false }, session: session)
                    }
                )
            )
            .disabled(isLocked)
            .opacity(isLocked ? 0.5 : 1)

            ManiCard {
                VStack(spacing: 0) {
                    ManiToggleRow(
                        title: "Use organisation theme",
                        subtitle: "Follow the colours your owner picked",
                        isOn: Binding(
                            get: { isLocked || themeStore.preference.useOrgTheme },
                            set: { value in themeStore.updatePreference({ $0.useOrgTheme = value }, session: session) }
                        ),
                        isLocked: isLocked
                    )
                    Divider()
                    ManiToggleRow(
                        title: "Larger text",
                        isOn: Binding(
                            get: { themeStore.preference.largerText },
                            set: { value in themeStore.updatePreference({ $0.largerText = value }, session: session) }
                        )
                    )
                    Divider()
                    ManiToggleRow(
                        title: "Compact lists",
                        isOn: Binding(
                            get: { themeStore.preference.compactLists },
                            set: { value in themeStore.updatePreference({ $0.compactLists = value }, session: session) }
                        )
                    )
                }
            }

            if isLocked {
                ManiNote("Your organisation has locked its theme. You can still switch between light and dark.", kind: .info)
            }

            SectionHeader(title: "Preview")
            HStack(spacing: ManiSpacing.sm) {
                ManiKPITile(title: "Today's sales", value: "₹12,400", isHighlighted: true)
                ManiKPITile(title: "Bills", value: "46")
            }
        }
        .navigationTitle("Appearance")
    }
}
