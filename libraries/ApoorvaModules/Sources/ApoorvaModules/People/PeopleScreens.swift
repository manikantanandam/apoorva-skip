//
//  PeopleScreens.swift
//  ApoorvaModules
//
//  Attendance (71) and salary (72).
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

private extension AttendanceStatus {
    var kind: ManiStatusKind {
        switch self {
        case .present: .success
        case .half: .warning
        case .absent, .leave: .error
        }
    }

    var mark: String {
        switch self {
        case .present: "✓"
        case .half: "½"
        case .absent: "✕"
        case .leave: "L"
        }
    }
}

// MARK: - Attendance (71)

public struct AttendanceView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: AttendanceViewModel
    private let canMark: Bool

    public init(viewModel: AttendanceViewModel, canMark: Bool) {
        self.viewModel = viewModel
        self.canMark = canMark
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "\(viewModel.presentToday) of \(viewModel.staff.count) present today")
            ManiSegmentedControl(selection: $viewModel.range, options: AttendanceViewModel.Range.allCases.map { ($0, $0.rawValue) })
            if viewModel.staff.isEmpty {
                ManiEmptyState(icon: .people, title: "No staff yet", message: "Invite staff from Admin → Members.")
            } else if viewModel.range == .today {
                RowsCard {
                    ForEach(viewModel.staff) { member in
                        let record = viewModel.record(for: member)
                        ManiListRow(avatar: ManiAvatar(initials: String(member.name.prefix(1))), title: member.name,
                                    subtitle: viewModel.summary(for: member),
                                    status: record.map { ($0.status.title, $0.status.kind) }) {
                            if canMark { Task { await viewModel.tap(member) } }
                        }
                    }
                }
                if canMark { ScreenSubtitle(text: "Tap to mark present. Tap again for half day, absent or leave.") }
            } else {
                grid
            }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        }
        .navigationTitle("Attendance")
        .task { await viewModel.load() }
    }

    private var grid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .center, horizontalSpacing: 6, verticalSpacing: 8) {
                GridRow {
                    Text("Staff").font(theme.typography.secondary.weight(.semibold)).gridColumnAlignment(.leading)
                    ForEach(viewModel.days, id: \.self) { day in
                        Text(viewModel.range == .week ? day.formatted(.dateTime.weekday(.narrow)) : day.formatted(.dateTime.day()))
                            .font(theme.typography.secondary)
                            .foregroundStyle(theme.base.textSecondary)
                    }
                }
                ForEach(viewModel.staff) { member in
                    GridRow {
                        Text(member.name).font(theme.typography.body).lineLimit(1)
                        ForEach(viewModel.days, id: \.self) { day in
                            let status = viewModel.record(for: member, on: day)?.status
                            Text(status?.mark ?? "·")
                                .font(theme.typography.secondary.weight(.semibold))
                                .frame(width: 22, height: 22)
                                .foregroundStyle(status == nil ? theme.base.textSecondary : theme.accent.on)
                                .background(status == .present ? theme.base.success : status == .half ? theme.base.warning
                                            : status == nil ? Color.clear : theme.base.error)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            .padding(ManiSpacing.md)
        }
        .background(theme.base.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.card))
    }
}

// MARK: - Salary (72)

public struct SalaryView: View {
    @Bindable private var viewModel: SalaryViewModel
    @State private var advanceFor: Member?

    public init(viewModel: SalaryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScreenScroll {
            HStack {
                Button { Task { await viewModel.step(-1) } } label: { Text("‹") }
                ScreenSubtitle(text: viewModel.title).frame(maxWidth: .infinity)
                Button { Task { await viewModel.step(1) } } label: { Text("›") }
            }
            .buttonStyle(.plain)
            if viewModel.rows.isEmpty {
                ManiEmptyState(icon: .wallet, title: "No salaries set", message: "Set base salary or commission on each member in Admin → Members.")
            } else {
                RowsCard {
                    ForEach(viewModel.rows) { row in
                        ManiListRow(title: row.member.name, subtitle: row.detail,
                                    value: Money.format(row.isPaid ? row.paid : row.payable),
                                    status: row.isPaid ? ("Paid", .success) : ("Due", .warning)) {
                            if !row.isPaid { advanceFor = row.member }
                        }
                    }
                }
            }
            if let member = advanceFor {
                SectionHeader(title: "Advance for \(member.name)")
                ManiInputField(label: "Amount", text: $viewModel.advanceText, placeholder: "₹", keyboard: .decimal)
                ManiButton("Give advance", kind: .outline, isEnabled: (Double(viewModel.advanceText) ?? 0) > 0) {
                    Task { if await viewModel.giveAdvance(to: member) { advanceFor = nil } }
                }
            }
            ManiSegmentedControl(selection: $viewModel.mode, options: [("cash", "Cash"), ("upi", "UPI"), ("bank", "Bank")])
            ManiNote("Paid salaries are added to Expenses automatically.", kind: .info)
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            if let row = viewModel.nextToPay {
                VStack(spacing: ManiSpacing.sm) {
                    ManiButton("Pay \(row.member.name) \(Money.format(row.payable))") { Task { _ = await viewModel.pay(row) } }
                    if advanceFor == nil {
                        ManiButton("Give advance", kind: .outline) { advanceFor = row.member }
                    }
                }
            }
        }
        .navigationTitle("Salary")
        .task { await viewModel.load() }
    }
}
