//
//  SetupScreens.swift
//  ApoorvaModules
//
//  Designs 13–15: shop type, shop profile, pick a look.
//

import SwiftUI
import ManiSwiftUIComponents
import ApoorvaModels

// MARK: - 13 What do you sell?

public struct ChooseVerticalView: View {
    @Bindable private var viewModel: ShopSetupViewModel
    private let onContinue: () -> Void

    public init(viewModel: ShopSetupViewModel, onContinue: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onContinue = onContinue
    }

    public var body: some View {
        ScreenScroll {
            ManiAppBar(title: "What do you sell?")
            ScreenSubtitle(text: "We tailor billing and theme to your shop")
            ManiStepIndicator(current: 1, total: 4)
            ManiPickList(
                options: Vertical.allCases.map {
                    ManiPickOption(value: $0, title: $0.title, subtitle: $0.subtitle,
                                   swatch: ThemeStore.swatchColor(for: $0.defaultAccent))
                },
                selection: Binding(get: { viewModel.vertical }, set: { viewModel.choose($0) })
            )
            ManiNote("More shop types are coming: handloom, stationery, pharmacy.")
        } bottom: {
            ManiButton("Continue", action: onContinue)
        }
        .navigationBarBackButtonHidden()
    }
}

// MARK: - 14 Your shop

public struct ShopSetupView: View {
    @Bindable private var viewModel: ShopSetupViewModel
    private let onContinue: () -> Void

    public init(viewModel: ShopSetupViewModel, onContinue: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onContinue = onContinue
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "Shown on bills and receipts")
            ManiStepIndicator(current: 2, total: 4)
            ManiInputField(label: "Your name", text: $viewModel.ownerName, placeholder: "Kiran Reddy")
            ManiInputField(label: "Shop name", text: $viewModel.shopName, placeholder: "Glitz Gifts & Fancy")
                .onChange(of: viewModel.shopName) { _, _ in viewModel.shopNameChanged() }
            ManiInputField(label: "Shop phone", text: $viewModel.phone, placeholder: "+91 98480 12345", keyboard: .phone)
            ManiInputField(label: "Address", text: $viewModel.address, placeholder: "Ameerpet, Hyderabad")
            ManiInputField(label: "Bill number prefix", text: $viewModel.billPrefix, placeholder: "GG-")
            ManiNote("Tax / GST is optional. Turn it on later in Settings → Tax only if you need it.")
        } bottom: {
            ManiButton("Continue", isEnabled: viewModel.canContinueShop, action: onContinue)
        }
        .navigationTitle("Your shop")
    }
}

// MARK: - 15 Pick a look

public struct PickLookView: View {
    @Bindable private var viewModel: ShopSetupViewModel
    private let themeStore: ThemeStore
    private let onFinished: () -> Void

    public init(viewModel: ShopSetupViewModel, themeStore: ThemeStore, onFinished: @escaping () -> Void) {
        self.viewModel = viewModel
        self.themeStore = themeStore
        self.onFinished = onFinished
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "Change anytime in Settings")
            ManiStepIndicator(current: 3, total: 4)
            ManiSegmentedControl(selection: $viewModel.scheme,
                                 options: ColorSchemePreference.allCases.map { (value: $0, title: $0.title) })
            SectionHeader(title: "Accent colour")
            ManiSwatchRow(options: AccentKey.allCases.map { (value: $0, title: $0.title, color: ThemeStore.swatchColor(for: $0)) },
                          selection: $viewModel.accent)
            SectionHeader(title: "Style")
            ManiSegmentedControl(selection: $viewModel.style,
                                 options: [(value: OrgSettings.VisualStyle.clean, title: "Clean"), (value: .bold, title: "Bold")])
            SectionHeader(title: "Preview")
            HStack(spacing: ManiSpacing.sm) {
                ManiKPITile(title: "Today's sales", value: "₹12,400", isHighlighted: true)
                ManiKPITile(title: "Bills", value: "46")
            }
            if let error = viewModel.errorMessage {
                ManiNote(error, kind: .error)
            }
        } bottom: {
            ManiButton("Finish setup", isLoading: viewModel.isCreating) {
                Task {
                    if await viewModel.finish() {
                        themeStore.updatePreference({ $0.scheme = viewModel.scheme; $0.useOrgTheme = true }, session: nil)
                        onFinished()
                    }
                }
            }
        }
        .navigationTitle("Pick a look")
        .onAppear(perform: preview)
        .onChange(of: viewModel.accent) { _, _ in preview() }
        .onChange(of: viewModel.style) { _, _ in preview() }
        .onChange(of: viewModel.scheme) { _, _ in preview() }
    }

    private func preview() {
        themeStore.preview(accent: viewModel.accent, style: viewModel.style, scheme: viewModel.scheme)
    }
}
