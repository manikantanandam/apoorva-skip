//
//  HomeView.swift
//  ApoorvaModules
//
//  Designs 16, 18–24: dashboard per shop type, first-run guide, plan usage banner, store switcher.
//

import SwiftUI
import ManiSwiftUIComponents
import ApoorvaModels

public enum HomeAction: Hashable, Sendable {
    case search, notifications, syncStatus, storeSwitcher
    case collectDue, cashEntry, addItem, dayClose
    case seeAllBills, bill(String)
    case restock, catalog
    case firstRunStep(String), createFirstBill, importItems
    case seePro
}

public struct HomeView: View {
    @Environment(\.maniTheme) private var theme
    private let session: AppSession
    @Bindable private var viewModel: HomeViewModel
    private let syncText: String
    private let onAction: (HomeAction) -> Void

    public init(session: AppSession, viewModel: HomeViewModel, syncText: String, onAction: @escaping (HomeAction) -> Void) {
        self.session = session
        self.viewModel = viewModel
        self.syncText = syncText
        self.onAction = onAction
    }

    public var body: some View {
        ScreenScroll {
            header

            if viewModel.showsFirstRunGuide {
                FirstRunGuideView(shopName: session.displayShopName, steps: viewModel.firstRunSteps,
                                  onStep: { onAction(.firstRunStep($0.id)) },
                                  onCreateBill: { onAction(.createFirstBill) },
                                  onImport: { onAction(.importItems) })
            } else {
                if viewModel.showsUsageBanner { usageBanner }
                kpiGrid
                SectionHeader(title: "Quick actions")
                FlowLayout {
                    ManiChip("Collect due", icon: .cashIn) { onAction(.collectDue) }
                    ManiChip("Cash entry", icon: .wallet) { onAction(.cashEntry) }
                    if session.can(.editInventory) { ManiChip("Add item", icon: .plus) { onAction(.addItem) } }
                    if session.can(.dayClose) { ManiChip("Day close", icon: .lock) { onAction(.dayClose) } }
                }
                verticalSection
                SectionHeader(title: "Recent bills", actionTitle: "See all") { onAction(.seeAllBills) }
                if viewModel.recentBills.isEmpty {
                    ScreenSubtitle(text: "No bills yet today.")
                } else {
                    RowsCard {
                        ForEach(Array(viewModel.recentBills.enumerated()), id: \.element.id) { index, sale in
                            if index > 0 { Divider() }
                            ManiListRow(title: sale.customerName.isEmpty ? "Walk-in" : sale.customerName,
                                        subtitle: "\(sale.displayNumber) · \(sale.timestamp.timeOnly)",
                                        value: Money.format(sale.netPayable),
                                        status: sale.isDue ? ("Due", .warning) : ("Paid", .success)) {
                                onAction(.bill(sale.id))
                            }
                        }
                    }
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Button { onAction(.storeSwitcher) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: ManiSpacing.xs) {
                        Text(session.stores.count > 1 ? session.currentStore.name : session.displayShopName)
                            .font(theme.typography.screenTitle)
                            .foregroundStyle(theme.base.text)
                            .lineLimit(1)
                        if session.stores.count > 1 {
                            ManiSwiftUIComponents.IconView(.chevronDown, size: 12, color: theme.base.textSecondary)
                        }
                    }
                    HStack(spacing: ManiSpacing.xs) {
                        Text(Date().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        Text("·")
                        Text(syncText)
                    }
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.base.textSecondary)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button { onAction(.syncStatus) } label: {
                ManiSwiftUIComponents.IconView(.sync, size: 18, color: theme.base.text)
            }
            Button { onAction(.notifications) } label: {
                ManiSwiftUIComponents.IconView(.bell, size: 18, color: theme.base.text)
            }
            .padding(.leading, ManiSpacing.sm)
            Button { onAction(.search) } label: {
                ManiSwiftUIComponents.IconView(.search, size: 18, color: theme.base.text)
            }
            .padding(.leading, ManiSpacing.sm)
        }
    }

    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ManiSpacing.sm) {
            ForEach(Array(viewModel.kpis.enumerated()), id: \.element.id) { index, kpi in
                VStack(alignment: .leading, spacing: 2) {
                    ManiKPITile(title: kpi.title, value: kpi.value, isHighlighted: index == 0)
                    if let caption = kpi.caption {
                        Text(caption)
                            .font(theme.typography.secondary)
                            .foregroundStyle(theme.base.textSecondary)
                            .padding(.leading, ManiSpacing.xs)
                    }
                }
            }
        }
    }

    private var usageBanner: some View {
        ManiCard {
            VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                Text("\(session.planStatus.billsUsed) of \(session.planStatus.freeBillLimit) free bills used this month")
                    .font(theme.typography.body.weight(.semibold))
                ManiProgressMeter(label: "Free plan", value: Double(session.planStatus.billsUsed),
                                  total: Double(session.planStatus.freeBillLimit))
                HStack(spacing: ManiSpacing.sm) {
                    ManiButton("See Pro · ₹\(session.planStatus.proPrice)/month") { onAction(.seePro) }
                    ManiButton("Remind me later", kind: .outline) { Task { await viewModel.snoozeUsageReminder() } }
                }
            }
        }
    }

    @ViewBuilder private var verticalSection: some View {
        switch session.vertical {
        case .fancy, .kirana:
            if !viewModel.lowStock.isEmpty {
                SectionHeader(title: "Low stock", actionTitle: "Restock") { onAction(.restock) }
                RowsCard {
                    ForEach(Array(viewModel.lowStock.prefix(3).enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider() }
                        ManiListRow(title: item.name, subtitle: "\(item.currentStock) left",
                                    value: item.sellPrice.map(Money.format), status: ("Low", .warning))
                    }
                }
            }
        case .jewellery:
            if !viewModel.trending.isEmpty {
                SectionHeader(title: "Trending designs", actionTitle: "Catalog") { onAction(.catalog) }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: ManiSpacing.sm) {
                    ForEach(viewModel.trending) { item in
                        ManiCategoryTile(title: "\(item.name)\n\(item.designCode ?? "")") { onAction(.catalog) }
                    }
                }
            }
        case .parlour:
            EmptyView()
        }
    }
}

/// Design 24: pick which store you're working in, with today's sales per store.
public struct StoreSwitcherView: View {
    private let session: AppSession
    private let salesByStore: [String: Double]
    @State private var selection: String
    private let onSwitched: () -> Void

    public init(session: AppSession, salesByStore: [String: Double], onSwitched: @escaping () -> Void) {
        self.session = session
        self.salesByStore = salesByStore
        self._selection = State(initialValue: session.currentStoreId)
        self.onSwitched = onSwitched
    }

    public var body: some View {
        ScreenScroll {
            ManiPickList(options: session.stores.map {
                ManiPickOption(value: $0.id, title: $0.name,
                               subtitle: "\($0.vertical.title) · today \(Money.format(salesByStore[$0.id] ?? 0))",
                               swatch: ThemeStore.swatchColor(for: $0.accent ?? $0.vertical.defaultAccent))
            }, selection: $selection)
            HStack(spacing: ManiSpacing.sm) {
                ManiKPITile(title: "All stores today", value: Money.format(salesByStore.values.reduce(0, +)), isHighlighted: true)
                ManiKPITile(title: "Stores", value: "\(session.stores.count)")
            }
        } bottom: {
            ManiButton("Switch") {
                session.selectStore(selection)
                onSwitched()
            }
        }
        .navigationTitle("Switch store")
    }
}
