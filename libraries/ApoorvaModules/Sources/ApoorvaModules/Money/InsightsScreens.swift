//
//  InsightsScreens.swift
//  ApoorvaModules
//
//  Overview (90), items (91), customers (92), staff (93), staff services (70), reports (94),
//  profit (95). One view model feeds every tab.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public enum InsightsTab: String, CaseIterable, Sendable {
    case overview = "Overview", profit = "Profit", items = "Items", customers = "Customers", staff = "Staff", reports = "Reports"
}

public struct InsightsView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: InsightsViewModel
    @State private var tab: InsightsTab
    @State private var exportURL: URL?
    private let isServiceShop: Bool
    private let canExport: Bool

    public init(viewModel: InsightsViewModel, tab: InsightsTab = .overview, isServiceShop: Bool, canExport: Bool) {
        self.viewModel = viewModel
        self._tab = State(initialValue: tab)
        self.isServiceShop = isServiceShop
        self.canExport = canExport
    }

    public var body: some View {
        ScreenScroll {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ManiSpacing.sm) {
                    ForEach(InsightsTab.allCases.filter { $0 != .reports || canExport }, id: \.self) { item in
                        ManiChip(item.rawValue, isSelected: tab == item) { tab = item }
                    }
                }
            }
            ManiSegmentedControl(selection: $viewModel.period, options: InsightsPeriod.allCases.map { ($0, $0.rawValue) })
            switch tab {
            case .overview: overview
            case .profit: profit
            case .items: items
            case .customers: customers
            case .staff: isServiceShop ? AnyView(serviceStaff) : AnyView(staff)
            case .reports: reports
            }
        }
        .navigationTitle("Insights")
        .toolbar {
            if canExport {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { tab = .reports } label: { ManiSwiftUIComponents.IconView(.download, size: 18, color: theme.base.text) }
                        .accessibilityLabel("Reports")
                }
            }
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(activityItems: [url]).presentationDetents([.medium, .large])
        }
        .task { await viewModel.load() }
    }

    private var metrics: ShopMetrics { viewModel.metrics }

    private func grid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: ManiSpacing.sm), GridItem(.flexible())], spacing: ManiSpacing.sm, content: content)
    }

    // MARK: Overview (90)

    private var overview: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.lg) {
            ManiLineChartCard(title: "Sales · \(Money.format(metrics.revenue))", caption: viewModel.trend.map { "\($0) vs previous" },
                              values: viewModel.salesSeries)
            grid {
                ManiKPITile(title: "Bills", value: "\(metrics.billCount)")
                ManiKPITile(title: "Avg bill", value: Money.format(metrics.averageBill))
                ManiKPITile(title: "Margin", value: "\(Int((metrics.margin * 100).rounded()))%")
                ManiKPITile(title: "New customers", value: "\(viewModel.newCustomers)")
            }
            let modes = [PaymentMode.upi, .cash, .card, .credit].compactMap { mode in
                (metrics.byMode[mode] ?? 0) > 0 ? ManiSplitSegment(mode.title, metrics.byMode[mode] ?? 0) : nil
            }
            if !modes.isEmpty { ManiSplitBarCard(title: "Payment modes", segments: modes) }
        }
    }

    // MARK: Profit (95)

    private var profit: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.lg) {
            let previous = viewModel.previousNetProfit
            let change = previous != 0 ? Int(((metrics.netProfit - previous) / abs(previous) * 100).rounded()) : nil
            grid {
                ManiKPITile(title: change.map { "Net profit · \($0 >= 0 ? "+" : "")\($0)%" } ?? "Net profit",
                            value: Money.format(metrics.netProfit), isHighlighted: true)
                ManiKPITile(title: "Sales", value: Money.format(metrics.revenue))
                ManiKPITile(title: "Cost of goods", value: Money.format(metrics.cost))
                ManiKPITile(title: "Expenses", value: Money.format(metrics.expenseTotal))
            }
            ManiBarChartCard(title: "Profit by week", bars: viewModel.profitByWeek.map { ManiChartDatum($0.label, max(0, $0.amount)) })
            if metrics.usesEstimatedCost {
                ManiNote("Items without a cost price use 80% of selling price. Add cost prices for exact profit.", kind: .info)
            }
        }
    }

    // MARK: Items (91)

    private var items: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.lg) {
            if !viewModel.topCategories.isEmpty {
                ManiBarChartCard(title: "Top categories", bars: viewModel.topCategories.map { ManiChartDatum($0.name, $0.amount) })
            }
            SectionHeader(title: "Best sellers")
            if viewModel.bestSellers.isEmpty {
                ScreenSubtitle(text: "No sales in this period.")
            } else {
                RowsCard {
                    ForEach(viewModel.bestSellers, id: \.id) { item in
                        ManiListRow(title: item.name, subtitle: "\(Int(item.quantity)) sold", value: Money.format(item.amount))
                    }
                }
            }
            SectionHeader(title: "Slow movers")
            if viewModel.slowMovers.isEmpty {
                ScreenSubtitle(text: "Everything in stock sold in the last 45 days.")
            } else {
                RowsCard {
                    ForEach(viewModel.slowMovers) { item in
                        ManiListRow(title: item.name, subtitle: "\(item.designCode.map { "\($0) · " } ?? "")0 sold in 45 days · \(item.currentStock) in stock",
                                    status: ("Slow", .warning))
                    }
                }
            }
        }
    }

    // MARK: Customers (92)

    private var customers: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.lg) {
            grid {
                ManiKPITile(title: "Repeat rate", value: "\(Int((viewModel.repeatRate * 100).rounded()))%")
                ManiKPITile(title: "New", value: "\(viewModel.newCustomers)")
                ManiKPITile(title: "Avg visits", value: String(format: "%.1f", viewModel.averageVisits))
                ManiKPITile(title: "Dues", value: Money.format(viewModel.totalDues), isHighlighted: viewModel.totalDues > 0)
            }
            ManiBarChartCard(title: "Dues ageing", bars: viewModel.duesAgeing.map { ManiChartDatum($0.label, $0.amount) }, highlightMax: false)
            SectionHeader(title: "Top customers")
            RowsCard {
                ForEach(viewModel.topCustomers, id: \.name) { customer in
                    ManiListRow(title: customer.name, subtitle: "\(customer.visits) visits", value: Money.format(customer.amount))
                }
            }
        }
    }

    // MARK: Staff (93)

    private var staff: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.lg) {
            if viewModel.staffSales.isEmpty {
                ScreenSubtitle(text: "No sales in this period.")
            } else {
                ManiBarChartCard(title: "Sales by staff", bars: viewModel.staffSales.map { ManiChartDatum($0.name, $0.amount) })
                RowsCard {
                    ForEach(viewModel.staffSales, id: \.id) { staff in
                        ManiListRow(title: staff.name, subtitle: "\(staff.bills) bills", value: Money.format(staff.amount))
                    }
                }
            }
            if viewModel.discountsAboveLimit > 0 {
                ManiNote("Discounts above \(Int(viewModel.discountLimit))% by staff: \(viewModel.discountsAboveLimit) in this period.", kind: .warning)
            }
        }
    }

    // MARK: Staff services (70)

    private var serviceStaff: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.lg) {
            if viewModel.serviceStaff.isEmpty {
                ManiEmptyState(icon: .people, title: "No services credited yet", message: "Pick \"Done by\" when billing services.")
            } else {
                ManiBarChartCard(title: "Revenue by staff", bars: viewModel.serviceStaff.map { ManiChartDatum($0.name, $0.amount) })
                RowsCard {
                    ForEach(viewModel.serviceStaff, id: \.id) { staff in
                        ManiListRow(title: staff.name,
                                    subtitle: "\(staff.services) services · commission \(Money.format(staff.commission))",
                                    value: Money.format(staff.amount),
                                    status: staff.commissionPercent > 0 ? ("\(Int(staff.commissionPercent))%", .neutral) : nil)
                    }
                }
            }
        }
    }

    // MARK: Reports (94)

    private var reports: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.lg) {
            ScreenSubtitle(text: "Download or share as CSV (opens in Excel and Sheets)")
            RowsCard {
                ForEach(InsightsViewModel.Report.allCases.filter { $0 != .tax || viewModel.taxIsOn }, id: \.self) { report in
                    ManiListRow(title: report.rawValue, subtitle: report.subtitle, value: "CSV") {
                        exportURL = viewModel.reportFile(report)
                    }
                }
            }
        }
    }
}
