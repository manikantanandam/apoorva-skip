//
//  PlanSheets.swift
//  ApoorvaModules
//
//  Designs 47 (free bill limit reached) and 48 (trial ending).
//

import SwiftUI
import ManiSwiftUIComponents
import ApoorvaModels

/// Shown when saving a bill past the free limit. Never blocks the customer: the grace bills let
/// the current bill through.
public struct PlanLimitView: View {
    private let status: PlanStatus
    private let onUpgrade: () -> Void
    private let onContinue: () -> Void
    private let onRemindTomorrow: () -> Void

    public init(status: PlanStatus, onUpgrade: @escaping () -> Void, onContinue: @escaping () -> Void,
                onRemindTomorrow: @escaping () -> Void) {
        self.status = status
        self.onUpgrade = onUpgrade
        self.onContinue = onContinue
        self.onRemindTomorrow = onRemindTomorrow
    }

    public var body: some View {
        ScreenScroll {
            ManiEmptyState(icon: .star, title: "You've used \(status.freeBillLimit) free bills",
                           message: "Upgrade to Pro for unlimited bills, staff accounts and reports.")
            ManiKeyValueSummary(rows: [
                ManiKeyValue("Bills this month", "\(status.billsUsed)"),
                ManiKeyValue("Grace bills left", "\(status.graceLeft) of \(status.graceBills)"),
                ManiKeyValue("Pro", "₹\(status.proPrice) / month")
            ], emphasizeLast: false)
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton("Upgrade to Pro", action: onUpgrade)
                if status.graceLeft > 0 {
                    ManiButton("Continue this bill (grace \(status.graceUsed + 1) of \(status.graceBills))", kind: .outline, action: onContinue)
                }
                ManiButton("Remind me tomorrow", kind: .secondary, action: onRemindTomorrow)
            }
        }
        .navigationTitle("Free plan limit")
    }
}

public struct TrialEndingView: View {
    private let status: PlanStatus
    private let billsDuringTrial: Int
    private let savedHours: Int
    private let onContinuePro: () -> Void
    private let onSwitchFree: () -> Void

    public init(status: PlanStatus, billsDuringTrial: Int, onContinuePro: @escaping () -> Void, onSwitchFree: @escaping () -> Void) {
        self.status = status
        self.billsDuringTrial = billsDuringTrial
        self.savedHours = max(1, billsDuringTrial / 20)
        self.onContinuePro = onContinuePro
        self.onSwitchFree = onSwitchFree
    }

    public var body: some View {
        ScreenScroll {
            ManiEmptyState(icon: .sparkles, title: "Your 30 days with Apoorva",
                           message: status.trialDaysLeft > 0 ? "\(status.trialDaysLeft) days left in your free trial." : "Your free trial has ended.")
            HStack(spacing: ManiSpacing.sm) {
                ManiKPITile(title: "Bills made", value: "\(billsDuringTrial)", isHighlighted: true)
                ManiKPITile(title: "Time saved", value: "~\(savedHours) h")
            }
            ManiNote("On Free you keep billing up to \(status.freeBillLimit) bills a month. Pro is ₹\(status.proPrice)/month.")
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton("Continue with Pro", action: onContinuePro)
                ManiButton("Switch to Free", kind: .outline, action: onSwitchFree)
            }
        }
        .navigationTitle("Trial")
    }
}
