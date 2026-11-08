//
//  ScreenKit.swift
//  ApoorvaModules
//
//  Small layout helpers composed from ManiSwiftUIComponents, shared by every screen.
//

import SwiftUI
import ManiSwiftUIComponents

/// Standard scrolling screen: themed background, 16pt padding, optional pinned bottom bar.
struct ScreenScroll<Content: View, Bottom: View>: View {
    @Environment(\.maniTheme) private var theme
    private let spacing: CGFloat
    private let content: Content
    private let bottom: Bottom

    init(spacing: CGFloat = ManiSpacing.lg,
         @ViewBuilder content: () -> Content,
         @ViewBuilder bottom: () -> Bottom = { EmptyView() }) {
        self.spacing = spacing
        self.content = content()
        self.bottom = bottom()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding(ManiSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.base.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottom
                .padding(.horizontal, ManiSpacing.lg)
                .padding(.bottom, ManiSpacing.sm)
        }
    }
}

/// Section title with an optional trailing link ("See all", "Statement").
struct SectionHeader: View {
    @Environment(\.maniTheme) private var theme
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(theme.typography.sectionHeader)
                .foregroundStyle(theme.base.text)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(theme.typography.secondary.weight(.semibold))
                    .foregroundStyle(theme.accent.accent)
            }
        }
    }
}

/// Subtitle under a screen title ("212 customers · ₹3,120 due").
struct ScreenSubtitle: View {
    @Environment(\.maniTheme) private var theme
    let text: String

    var body: some View {
        Text(text)
            .font(theme.typography.secondary)
            .foregroundStyle(theme.base.textSecondary)
    }
}

/// Tappable row with icon, title, optional subtitle/value and a chevron — settings and menus.
struct NavRow: View {
    @Environment(\.maniTheme) private var theme
    let icon: ManiIconName?
    let title: String
    var subtitle: String?
    var value: String?
    var badge: (text: String, kind: ManiStatusKind)?
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ManiSpacing.md) {
                if let icon {
                    ManiSwiftUIComponents.IconView(icon, size: 18, color: isDestructive ? theme.base.error : theme.accent.accent)
                        .frame(width: 28)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(theme.typography.body.weight(.medium))
                        .foregroundStyle(isDestructive ? theme.base.error : theme.base.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(theme.typography.secondary)
                            .foregroundStyle(theme.base.textSecondary)
                    }
                }
                Spacer()
                if let badge {
                    ManiStatusBadge(badge.text, kind: badge.kind)
                }
                if let value {
                    Text(value)
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.base.textSecondary)
                }
                if !isDestructive {
                    ManiSwiftUIComponents.IconView(.chevronRight, size: 12, color: theme.base.textSecondary)
                }
            }
            .padding(.vertical, ManiSpacing.sm)
            .frame(minHeight: ManiTouchTarget.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A card containing rows separated by dividers.
struct RowsCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ManiCard(padding: ManiSpacing.md) {
            VStack(spacing: 0) {
                content
            }
        }
    }
}

/// Chips that wrap onto new lines (quick actions, More menu groups).
struct FlowLayout: Layout {
    var spacing: CGFloat = ManiSpacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? maxX : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Formats rupee amounts with en-IN grouping: ₹1,23,450.
enum Money {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func format(_ amount: Double) -> String {
        let sign = amount < 0 ? "-" : ""
        return sign + "₹" + (formatter.string(from: NSNumber(value: abs(amount).rounded())) ?? "0")
    }
}

extension Date {
    var shortDay: String { formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
    var timeOnly: String { formatted(date: .omitted, time: .shortened) }
}
