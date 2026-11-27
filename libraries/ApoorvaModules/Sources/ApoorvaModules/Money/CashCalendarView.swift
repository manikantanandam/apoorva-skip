//
//  CashCalendarView.swift
//  ApoorvaModules
//
//  Month calendar for the Cashflow day screen: pick any past day, with closed days marked green.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

/// Month grid maths, kept apart from the view so it can be tested.
enum CashCalendarGrid {
    /// Every day of the month, padded with `nil` before the 1st so each date lands in its weekday column.
    static func cells(for month: Date, calendar: Calendar = .current) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let dayCount = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        let days: [Date?] = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        return Array(repeating: nil, count: leading) + days
    }

    /// Short weekday names starting at the calendar's first weekday.
    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    static func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}

public struct CashCalendarView: View {
    @Environment(\.maniTheme) private var theme
    private let selected: Date
    private let closedDayKeys: Set<String>
    private let onPick: (Date) -> Void
    @State private var month: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    public init(selected: Date, closedDayKeys: Set<String>, onPick: @escaping (Date) -> Void) {
        self.selected = selected
        self.closedDayKeys = closedDayKeys
        self.onPick = onPick
        _month = State(initialValue: CashCalendarGrid.startOfMonth(selected))
    }

    private var isCurrentMonth: Bool { calendar.isDate(month, equalTo: Date(), toGranularity: .month) }

    public var body: some View {
        VStack(spacing: ManiSpacing.md) {
            HStack {
                Button { shiftMonth(-1) } label: { ManiSwiftUIComponents.IconView(.chevronRight, size: 14).rotationEffect(.degrees(180)) }
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(theme.typography.screenTitle)
                    .foregroundStyle(theme.base.text)
                    .frame(maxWidth: .infinity)
                Button { shiftMonth(1) } label: { ManiSwiftUIComponents.IconView(.chevronRight, size: 14) }
                    .disabled(isCurrentMonth)
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(CashCalendarGrid.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.base.textSecondary)
                }
                ForEach(Array(CashCalendarGrid.cells(for: month).enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day) } else { Color.clear.frame(height: 40) }
                }
            }

            HStack(spacing: ManiSpacing.lg) {
                legend(color: theme.base.success, text: "Day closed")
                legend(color: nil, text: "Selected")
                Spacer()
                Button("Today") { onPick(Date()) }
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isFuture = calendar.startOfDay(for: day) > calendar.startOfDay(for: Date())
        let isClosed = closedDayKeys.contains(day.dayKey)
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let isToday = calendar.isDateInToday(day)
        return Button { onPick(day) } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(isToday ? .body.weight(.bold) : .body)
                .foregroundStyle(isClosed ? Color.white : (isFuture ? theme.base.textSecondary.opacity(0.5) : theme.base.text))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Circle().fill(isClosed ? theme.base.success : Color.clear))
                .overlay(Circle().stroke(isSelected ? theme.accent.accent : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)) + (isClosed ? ", closed" : "")))
    }

    private func legend(color: Color?, text: String) -> some View {
        HStack(spacing: ManiSpacing.xs) {
            Circle()
                .fill(color ?? Color.clear)
                .overlay(Circle().stroke(color == nil ? theme.accent.accent : Color.clear, lineWidth: 2))
                .frame(width: 12, height: 12)
            Text(text)
                .font(theme.typography.secondary)
                .foregroundStyle(theme.base.textSecondary)
        }
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: month) else { return }
        if delta > 0 && calendar.startOfDay(for: next) > calendar.startOfDay(for: Date()) { return }
        month = next
    }
}
