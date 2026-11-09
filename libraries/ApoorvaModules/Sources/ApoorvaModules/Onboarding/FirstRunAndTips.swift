//
//  FirstRunAndTips.swift
//  ApoorvaModules
//
//  Design 16 (home before the first bill) and 31 (one-time tips overlay).
//

import SwiftUI
import ManiSwiftUIComponents

public struct FirstRunStep: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let isDone: Bool

    public init(id: String, title: String, subtitle: String, isDone: Bool) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.isDone = isDone
    }
}

/// "Welcome! 3 quick steps" — shown on Home until the shop has its first bill.
public struct FirstRunGuideView: View {
    @Environment(\.maniTheme) private var theme
    private let shopName: String
    private let steps: [FirstRunStep]
    private let onStep: (FirstRunStep) -> Void
    private let onCreateBill: () -> Void
    private let onImport: () -> Void

    public init(shopName: String, steps: [FirstRunStep], onStep: @escaping (FirstRunStep) -> Void,
                onCreateBill: @escaping () -> Void, onImport: @escaping () -> Void) {
        self.shopName = shopName
        self.steps = steps
        self.onStep = onStep
        self.onCreateBill = onCreateBill
        self.onImport = onImport
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.lg) {
            ManiEmptyState(icon: .sparkles, title: "Welcome! 3 quick steps",
                           message: "Get \(shopName) ready to bill in a couple of minutes.")
            RowsCard {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    if index > 0 { Divider() }
                    Button { onStep(step) } label: {
                        HStack(spacing: ManiSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(step.isDone ? theme.base.success : theme.accent.soft)
                                    .frame(width: 28, height: 28)
                                if step.isDone {
                                    ManiSwiftUIComponents.IconView(.check, size: 12, color: .white)
                                } else {
                                    Text("\(index + 1)").font(.footnote.weight(.bold)).foregroundStyle(theme.accent.accent)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title).font(theme.typography.body.weight(.medium)).foregroundStyle(theme.base.text)
                                Text(step.subtitle).font(theme.typography.secondary).foregroundStyle(theme.base.textSecondary)
                            }
                            Spacer()
                            if !step.isDone {
                                ManiSwiftUIComponents.IconView(.plus, size: 14, color: theme.accent.accent)
                            }
                        }
                        .padding(.vertical, ManiSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            ManiButton("Create first bill", action: onCreateBill)
            ManiButton("Import items from Excel/CSV", kind: .outline, action: onImport)
        }
    }
}

/// One-time coach marks per screen ("Tip 1 of 3"), remembered on the device.
public struct TipsOverlayModifier: ViewModifier {
    @Environment(\.maniTheme) private var theme
    @AppStorage private var seen: Bool
    @State private var index = 0
    private let tips: [String]

    public init(screen: String, tips: [String]) {
        self.tips = tips
        self._seen = AppStorage(wrappedValue: false, "apoorva.tips.\(screen)")
    }

    public func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if !seen && !tips.isEmpty {
                VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                    Text("Tip \(index + 1) of \(tips.count)")
                        .font(theme.typography.secondary.weight(.semibold))
                        .foregroundStyle(theme.accent.on.opacity(0.8))
                    Text(tips[index])
                        .font(theme.typography.body)
                        .foregroundStyle(theme.accent.on)
                    HStack {
                        Button("Skip tips") { seen = true }
                            .foregroundStyle(theme.accent.on.opacity(0.8))
                        Spacer()
                        Button(index + 1 < tips.count ? "Next" : "Got it") {
                            if index + 1 < tips.count { index += 1 } else { seen = true }
                        }
                        .font(.body.weight(.bold))
                        .foregroundStyle(theme.accent.on)
                    }
                }
                .padding(ManiSpacing.lg)
                .background(theme.accent.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
                .padding(ManiSpacing.lg)
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

public extension View {
    /// Shows one-time tips for a screen until dismissed.
    func tipsOverlay(screen: String, tips: [String]) -> some View {
        modifier(TipsOverlayModifier(screen: screen, tips: tips))
    }
}
