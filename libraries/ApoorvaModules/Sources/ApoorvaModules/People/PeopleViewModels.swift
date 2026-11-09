//
//  PeopleViewModels.swift
//  ApoorvaModules
//
//  Attendance (71) and salary (72).
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

// MARK: - Attendance (71)

@MainActor
@Observable
public final class AttendanceViewModel {
    public enum Range: String, CaseIterable, Sendable { case today = "Today", week = "Week", month = "Month" }

    public var range: Range = .today
    public private(set) var staff: [Member] = []
    public private(set) var records: [AttendanceRecord] = []
    public var errorMessage: String?

    private let memberRepository: any OrgCollectionRepositoryProtocol<Member>
    private let attendanceRepository: any OrgCollectionRepositoryProtocol<AttendanceRecord>
    private let people: PeopleRepositoryProtocol
    private let actorId: String

    public init(memberRepository: any OrgCollectionRepositoryProtocol<Member>,
                attendanceRepository: any OrgCollectionRepositoryProtocol<AttendanceRecord>, people: PeopleRepositoryProtocol, actorId: String) {
        self.memberRepository = memberRepository
        self.attendanceRepository = attendanceRepository
        self.people = people
        self.actorId = actorId
    }

    public func load() async {
        staff = ((try? await memberRepository.all()) ?? []).filter { $0.isActive && !$0.isDeleted }.sorted { $0.name < $1.name }
        records = ((try? await attendanceRepository.all()) ?? []).filter { !$0.isDeleted }
    }

    public func record(for member: Member, on day: Date = Date()) -> AttendanceRecord? {
        records.first { $0.id == "\(day.dayKey)_\(member.id)" }
    }

    /// First tap marks present (with the time in); later taps cycle half → absent → leave → present.
    public func tap(_ member: Member) async {
        let now = Date()
        var record = record(for: member, on: now)
            ?? AttendanceRecord(memberId: member.id, memberName: member.name, day: now, status: .absent, markedBy: actorId)
        let isFirst = self.record(for: member, on: now) == nil
        record.status = isFirst ? .present : record.status.next
        if record.status == .present && record.inAt == nil { record.inAt = now }
        record.markedBy = actorId
        record.updatedAt = now
        do {
            try await people.mark(record)
            records.removeAll { $0.id == record.id }
            records.append(record)
        } catch {
            errorMessage = "Couldn't save attendance."
        }
    }

    public var presentToday: Int { staff.filter { record(for: $0)?.status == .present }.count }

    /// Days shown in the week/month grid, oldest first.
    public var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch range {
        case .today: return [today]
        case .week: return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        case .month:
            let start = calendar.dateInterval(of: .month, for: today)!.start
            let count = (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1
            return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        }
    }

    public func summary(for member: Member) -> String {
        guard let record = record(for: member) else { return "Not marked" }
        switch record.status {
        case .present: return record.inAt.map { "In \($0.timeOnly)" } ?? "Present"
        case .half: return "Half day"
        case .absent: return "Absent"
        case .leave: return "Leave"
        }
    }
}

// MARK: - Salary (72)

@MainActor
@Observable
public final class SalaryViewModel {
    public struct Row: Identifiable, Sendable {
        public var id: String { member.id }
        public let member: Member
        public let base: Double
        public let commission: Double
        public let advances: Double
        public let halfDays: Int
        public let absentDays: Int
        public let deductions: Double
        public let paid: Double

        public var payable: Double { max(0, base + commission - advances - deductions) }
        public var isPaid: Bool { paid > 0 }

        public var detail: String {
            var parts = [Money.format(base)]
            if commission > 0 { parts[0] += " + commission \(Money.format(commission))" }
            if halfDays > 0 { parts.append("\(halfDays) half day\(halfDays == 1 ? "" : "s")") }
            if absentDays > 0 { parts.append("\(absentDays) absent") }
            if advances > 0 { parts.append("advance \(Money.format(advances))") }
            return parts.joined(separator: " · ")
        }
    }

    public var month = Date()
    public private(set) var rows: [Row] = []
    public var advanceText = ""
    public var mode = "cash"
    public var errorMessage: String?

    private let memberRepository: any OrgCollectionRepositoryProtocol<Member>
    private let attendanceRepository: any OrgCollectionRepositoryProtocol<AttendanceRecord>
    private let salaryRepository: any OrgCollectionRepositoryProtocol<SalaryPayment>
    private let saleRepository: SaleRepositoryProtocol
    private let people: PeopleRepositoryProtocol
    private let actorId: String

    public init(memberRepository: any OrgCollectionRepositoryProtocol<Member>,
                attendanceRepository: any OrgCollectionRepositoryProtocol<AttendanceRecord>,
                salaryRepository: any OrgCollectionRepositoryProtocol<SalaryPayment>, saleRepository: SaleRepositoryProtocol,
                people: PeopleRepositoryProtocol, actorId: String) {
        self.memberRepository = memberRepository
        self.attendanceRepository = attendanceRepository
        self.salaryRepository = salaryRepository
        self.saleRepository = saleRepository
        self.people = people
        self.actorId = actorId
    }

    public var monthKey: String { SalaryPayment.monthKey(month) }
    public var title: String { month.formatted(.dateTime.month(.wide).year()) }

    /// Base salary, commission on services done this month, minus advances and attendance (a day = base/30).
    public func load() async {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return }
        let members = ((try? await memberRepository.all()) ?? []).filter { $0.isActive && !$0.isDeleted }
        let attendance = ((try? await attendanceRepository.all()) ?? []).filter { !$0.isDeleted && interval.contains($0.day) }
        let payments = ((try? await salaryRepository.all()) ?? []).filter { !$0.isDeleted && $0.month == monthKey }
        let sales = ((try? await saleRepository.getSales()) ?? []).filter { !$0.isCancelled && !$0.isReturn && interval.contains($0.timestamp) }
        rows = members.filter { ($0.baseSalary ?? 0) > 0 || ($0.commissionPercent ?? 0) > 0 }.map { member in
            let base = member.baseSalary ?? 0
            let services = sales.flatMap(\.items).filter { $0.doneByStaffId == member.id }.reduce(0) { $0 + $1.totalAmount }
            let commission = (services * (member.commissionPercent ?? 0) / 100).rounded()
            let mine = attendance.filter { $0.memberId == member.id }
            let halfDays = mine.filter { $0.status == .half }.count
            let absentDays = mine.filter { $0.status == .absent }.count
            let perDay = base / 30
            let deductions = (perDay * (Double(halfDays) / 2 + Double(absentDays))).rounded()
            let memberPayments = payments.filter { $0.memberId == member.id }
            return Row(member: member, base: base, commission: commission,
                       advances: memberPayments.filter { $0.kind == .advance }.reduce(0) { $0 + $1.amount },
                       halfDays: halfDays, absentDays: absentDays, deductions: deductions,
                       paid: memberPayments.filter { $0.kind == .salary }.reduce(0) { $0 + $1.amount })
        }
        .sorted { !$0.isPaid && $1.isPaid || ($0.isPaid == $1.isPaid && $0.member.name < $1.member.name) }
    }

    public var nextToPay: Row? { rows.first { !$0.isPaid && $0.payable > 0 } }

    public func pay(_ row: Row) async -> Bool {
        guard row.payable > 0 else { return false }
        return await record(SalaryPayment(memberId: row.member.id, memberName: row.member.name, month: monthKey, kind: .salary,
                                          amount: row.payable, mode: mode, createdBy: actorId))
    }

    public func giveAdvance(to member: Member) async -> Bool {
        guard let amount = Double(advanceText), amount > 0 else { return false }
        let ok = await record(SalaryPayment(memberId: member.id, memberName: member.name, month: monthKey, kind: .advance,
                                            amount: amount, mode: mode, createdBy: actorId))
        if ok { advanceText = "" }
        return ok
    }

    private func record(_ payment: SalaryPayment) async -> Bool {
        do {
            try await people.pay(payment)
            await load()
            return true
        } catch {
            errorMessage = "Couldn't record the payment."
            return false
        }
    }

    public func step(_ months: Int) async {
        guard let next = Calendar.current.date(byAdding: .month, value: months, to: month), next <= Date() else { return }
        month = next
        await load()
    }
}
