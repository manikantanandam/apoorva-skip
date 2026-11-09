//
//  ShopSetupViewModel.swift
//  ApoorvaModules
//

import Foundation
import ApoorvaModels
import ApoorvaServices
import ApoorvaRepository

/// Steps 1–3 of shop setup (designs 13–15), shared across the three screens. The org is created
/// on "Finish setup", so a half-finished setup leaves nothing behind in Firestore.
@MainActor
@Observable
public final class ShopSetupViewModel {
    public var vertical: Vertical = .kirana
    public var ownerName = ""
    public var shopName = ""
    public var phone = ""
    public var address = ""
    public var billPrefix = "A-"
    public var accent: AccentKey = Vertical.kirana.defaultAccent
    public var style: OrgSettings.VisualStyle = .clean
    public var scheme: ColorSchemePreference = .system
    public var isCreating = false
    public var errorMessage: String?

    private let authService: AuthServicing
    private let setupService: OrganizationSetupServicing
    private let platformTrialDays: () -> Int

    public init(authService: AuthServicing, setupService: OrganizationSetupServicing, platformTrialDays: @escaping () -> Int = { 30 }) {
        self.authService = authService
        self.setupService = setupService
        self.platformTrialDays = platformTrialDays
    }

    public func choose(_ vertical: Vertical) {
        self.vertical = vertical
        accent = vertical.defaultAccent
        if billPrefix == "A-" || billPrefix.isEmpty {
            billPrefix = Self.suggestedPrefix(for: shopName)
        }
    }

    public var canContinueShop: Bool {
        !shopName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public func shopNameChanged() {
        billPrefix = Self.suggestedPrefix(for: shopName)
    }

    /// Creates the org and owner profile. The session listener then moves the app to Home.
    public func finish() async -> Bool {
        guard let account = authService.currentAccount else {
            errorMessage = "Your session expired. Sign in again."
            return false
        }
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        do {
            let owner = ownerName.trimmingCharacters(in: .whitespaces)
            _ = try await setupService.createShop(NewShop(
                ownerName: owner.isEmpty ? (account.email?.components(separatedBy: "@").first ?? "Owner") : owner,
                shopName: shopName.trimmingCharacters(in: .whitespaces),
                phone: phone,
                address: address,
                billPrefix: billPrefix.isEmpty ? "A-" : billPrefix,
                vertical: vertical,
                theme: OrgSettings.Theme(accent: accent, style: style),
                trialDays: platformTrialDays()
            ), owner: account)
            return true
        } catch {
            errorMessage = "Couldn't create your shop. Check your connection and try again."
            return false
        }
    }

    static func suggestedPrefix(for name: String) -> String {
        let initials = name.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return (initials.isEmpty ? "A" : initials) + "-"
    }
}
