//
//  OrganizationDetailsView.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct OrganizationDetailsView: View {
    @Bindable private var viewModel: OrganizationDetailsViewModel

    public init(viewModel: OrganizationDetailsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScreenScroll {
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
            if viewModel.isLoading && viewModel.organization == nil {
                ProgressView().frame(maxWidth: .infinity)
            }
            header
            organizationSection
            profileSection
            planSection
            taxAndReceiptsSection
            paymentsSection
            accountsSection
            storesSection
            teamSection
        }
        .navigationTitle("Organization details")
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    // MARK: - Sections

    private var header: some View {
        let profile = viewModel.settings.profile
        let name = profile.shopName.isEmpty ? (viewModel.organization?.name ?? "Organization") : profile.shopName
        let status = viewModel.organization?.status ?? "—"
        let vertical = profile.vertical?.title ?? "Shop"
        return ManiHeroAmount(name, caption: "\(vertical) · \(status)", icon: .store)
    }

    @ViewBuilder private var organizationSection: some View {
        if let org = viewModel.organization {
            SectionHeader(title: "Organization")
            ManiKeyValueSummary(rows: [
                ManiKeyValue("Name", org.name),
                ManiKeyValue("Organization ID", org.id),
                ManiKeyValue("Status", org.status),
                ManiKeyValue("Created", org.createdAt.detailDate),
                ManiKeyValue("Minimum app version", org.minVersion),
                ManiKeyValue("Theme", org.currentTheme)
            ], emphasizeLast: false)
        }
    }

    private var profileSection: some View {
        let profile = viewModel.settings.profile
        return VStack(alignment: .leading, spacing: ManiSpacing.sm) {
            SectionHeader(title: "Shop profile")
            ManiKeyValueSummary(rows: [
                ManiKeyValue("Shop name", dash(profile.shopName)),
                ManiKeyValue("Shop type", profile.vertical?.title ?? "—"),
                ManiKeyValue("Phone", dash(profile.phone)),
                ManiKeyValue("Address", dash(profile.address)),
                ManiKeyValue("Bill prefix", dash(profile.billPrefix)),
                ManiKeyValue("Setup completed", profile.setupCompletedAt?.detailDate ?? "Not yet"),
                ManiKeyValue("Opening balances", profile.openingBalancesSavedAt?.detailDate ?? "Not saved")
            ], emphasizeLast: false)
        }
    }

    private var planSection: some View {
        let plan = viewModel.planStatus
        var rows = [ManiKeyValue("Plan", plan.tier.rawValue.capitalized)]
        if plan.tier == .trial { rows.append(ManiKeyValue("Trial days left", "\(plan.trialDaysLeft)")) }
        if !plan.isUnlimited { rows.append(ManiKeyValue("Bills this month", "\(plan.billsUsed) of \(plan.freeBillLimit)")) }
        else { rows.append(ManiKeyValue("Bills this month", "\(plan.billsUsed)")) }
        return VStack(alignment: .leading, spacing: ManiSpacing.sm) {
            SectionHeader(title: "Plan")
            ManiKeyValueSummary(rows: rows, emphasizeLast: false)
        }
    }

    private var taxAndReceiptsSection: some View {
        let tax = viewModel.settings.tax
        let receipt = viewModel.settings.receipt
        return VStack(alignment: .leading, spacing: ManiSpacing.sm) {
            SectionHeader(title: "Tax & receipts")
            ManiKeyValueSummary(rows: [
                ManiKeyValue("Tax", taxMode(tax.mode)),
                ManiKeyValue("Tax rate", tax.mode == .off ? "—" : "\(tax.ratePercent.formatted())%"),
                ManiKeyValue("GSTIN", dash(tax.gstin)),
                ManiKeyValue("Next bill number", "\(receipt.nextBillNumber)"),
                ManiKeyValue("Paper size", paperSize(receipt.paperSize)),
                ManiKeyValue("Printer", receipt.printerName ?? "—")
            ], emphasizeLast: false)
        }
    }

    private var paymentsSection: some View {
        let payments = viewModel.settings.payments
        return VStack(alignment: .leading, spacing: ManiSpacing.sm) {
            SectionHeader(title: "Payments")
            ManiKeyValueSummary(rows: [
                ManiKeyValue("UPI ID", dash(payments.upiId)),
                ManiKeyValue("UPI verified", payments.upiVerified ? "Yes" : "No"),
                ManiKeyValue("Payment modes", payments.enabledModes.isEmpty ? "—" : payments.enabledModes.joined(separator: ", ")),
                ManiKeyValue("Round off", payments.roundOff ? "On" : "Off")
            ], emphasizeLast: false)
        }
    }

    @ViewBuilder private var accountsSection: some View {
        if let accounts = viewModel.organization?.accounts, !accounts.isEmpty {
            SectionHeader(title: "Accounts")
            RowsCard {
                ForEach(Array(accounts.enumerated()), id: \.offset) { index, account in
                    if index > 0 { Divider() }
                    ManiListRow(title: account.name, subtitle: account.type.rawValue.capitalized,
                                value: Money.format(account.currentBalance))
                }
            }
        }
    }

    @ViewBuilder private var storesSection: some View {
        SectionHeader(title: "Stores (\(max(viewModel.stores.count, 1)))")
        if viewModel.stores.isEmpty {
            ScreenSubtitle(text: "One default store.")
        } else {
            RowsCard {
                ForEach(Array(viewModel.stores.enumerated()), id: \.element.id) { index, store in
                    if index > 0 { Divider() }
                    ManiListRow(title: store.name,
                                subtitle: [store.vertical.title, store.address].filter { !$0.isEmpty }.joined(separator: " · "),
                                status: store.isLive ? ("Live", .success) : ("Setting up", .neutral))
                }
            }
        }
    }

    @ViewBuilder private var teamSection: some View {
        SectionHeader(title: "Team (\(viewModel.activeMembers.count))")
        if viewModel.activeMembers.isEmpty && viewModel.pendingInvites.isEmpty {
            ScreenSubtitle(text: "No team members yet.")
        } else {
            RowsCard {
                ForEach(Array(viewModel.activeMembers.enumerated()), id: \.element.id) { index, member in
                    if index > 0 { Divider() }
                    ManiListRow(avatar: ManiAvatar(initials: initials(member.name)),
                                title: member.name.isEmpty ? member.email : member.name,
                                subtitle: member.email,
                                status: (member.role.title, roleKind(member.role)))
                }
                ForEach(viewModel.pendingInvites) { invite in
                    if !viewModel.activeMembers.isEmpty || invite.id != viewModel.pendingInvites.first?.id { Divider() }
                    ManiListRow(avatar: ManiAvatar(initials: initials(invite.name)),
                                title: invite.name,
                                subtitle: invite.email,
                                status: ("\(invite.role.title) · Pending", .warning))
                }
            }
        }
    }

    private func initials(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "?" : String(trimmed.prefix(1)).uppercased()
    }

    private func roleKind(_ role: OrgRole) -> ManiStatusKind {
        switch role {
        case .owner: .success
        case .manager: .warning
        case .cashier, .accountant: .neutral
        }
    }

    // MARK: - Formatting

    private func dash(_ text: String) -> String { text.isEmpty ? "—" : text }

    private func taxMode(_ mode: OrgSettings.TaxMode) -> String {
        switch mode {
        case .off: "Off"
        case .sameForAll: "Same rate for all items"
        case .perItem: "Per item"
        }
    }

    private func paperSize(_ size: OrgSettings.PaperSize) -> String {
        switch size {
        case .mm58: "58 mm"
        case .mm80: "80 mm"
        case .a4: "A4"
        }
    }
}

private extension Date {
    var detailDate: String { formatted(date: .abbreviated, time: .omitted) }
}
