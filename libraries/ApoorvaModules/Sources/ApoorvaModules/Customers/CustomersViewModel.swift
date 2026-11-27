//
//  CustomersViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 15/10/26.
//

import Foundation
import SkipFuse
import Observation
import ApoorvaModels
import ApoorvaRepository
import ManiLogger

private let logger = AppLogger(category: .ui)

public enum FileFormat: String, Identifiable, CaseIterable {
    case csv = "CSV File (.csv)"
    case vcf = "VCard File (.vcf)"

    public var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .csv: return "tablecells"
        case .vcf: return "person.crop.rectangle"
        }
    }
}

public enum CustomerFilter: String, CaseIterable, Sendable {
    case all = "All"
    case withDues = "With dues"
    case regulars = "Regulars"
    case newThisMonth = "New this month"
}

public enum CustomerSort: String, CaseIterable, Sendable {
    case recent = "Recent"
    case highestDue = "Highest due"
    case topSpenders = "Top spenders"
    case name = "A–Z"
}

extension Customer {
    /// "••1463" style form for shared screens.
    var maskedPhone: String { phone.count > 4 ? "••\(phone.suffix(4))" : phone }

    /// Five or more visits.
    var isRegular: Bool { totalSales >= 5 }

    var lastVisit: Date? { lastPurchaseDate.map(Date.init(timeIntervalSince1970:)) }

    var lastVisitText: String {
        guard let lastVisit else { return "no visits yet" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: lastVisit),
                                                   to: Calendar.current.startOfDay(for: Date())).day ?? 0
        switch days {
        case ..<1: return "last visit today"
        case 1: return "yesterday"
        case 2..<7: return "\(days) days ago"
        case 7..<14: return "1 week ago"
        case 14..<60: return "\(days / 7) weeks ago"
        default: return lastVisit.shortDay
        }
    }
}

/// Customers with dues filter (design 61).
@MainActor
@Observable
public class CustomerListViewModel {

    var customers: [Customer] = []
    var searchText: String = ""
    public var filter: CustomerFilter = .all
    public var sort: CustomerSort = .recent

    let repository: CustomerRepositoryProtocol

    public init(repository: CustomerRepositoryProtocol) {
        self.repository = repository
    }

    public var filteredCustomers: [Customer] {
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        var list: [Customer]
        switch filter {
        case .all: list = customers
        case .withDues: list = customers.filter { $0.dueBalance > 0 }
        case .regulars: list = customers.filter(\.isRegular)
        case .newThisMonth: list = customers.filter { Date(timeIntervalSince1970: $0.createdAt) >= startOfMonth }
        }
        if !searchText.isEmpty {
            let digits = searchText.filter(\.isNumber)
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) || (!digits.isEmpty && $0.phone.contains(digits))
            }
        }
        switch sort {
        case .recent:
            // `customers` is already newest-first; "With dues" keeps its biggest-first order.
            return filter == .withDues ? list.sorted { $0.dueBalance > $1.dueBalance } : list
        case .highestDue: return list.sorted { $0.dueBalance > $1.dueBalance }
        case .topSpenders: return list.sorted { $0.totalAmountSpent > $1.totalAmountSpent }
        case .name: return list.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
    }

    /// Letter-grouped rows, used only when sorted A–Z.
    public var alphabeticalSections: [(letter: String, customers: [Customer])] {
        var sections: [(letter: String, customers: [Customer])] = []
        for customer in filteredCustomers {
            let first = String(customer.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
            let letter = first.isEmpty || !(first.first?.isLetter ?? false) ? "#" : first
            if let last = sections.indices.last, sections[last].letter == letter {
                sections[last].customers.append(customer)
            } else {
                sections.append((letter, [customer]))
            }
        }
        return sections
    }

    /// Jumps to the dues list from the summary header.
    public func showDues() {
        filter = .withDues
    }

    public var totalDue: Double { customers.reduce(0) { $0 + max(0, $1.dueBalance) } }

    public var subtitle: String {
        let count = customers.count == 1 ? "1 customer" : "\(customers.count) customers"
        return totalDue > 0 ? "\(count) · \(Money.format(totalDue)) due" : count
    }

    public func prepareDate() async {
        do {
            self.customers = sortedByRecent(try await repository.getCustomers())
            try await repository.sync(force: false)
            self.customers = sortedByRecent(try await repository.getCustomers())
        } catch {
            logger.error("Customers failed to load: \(error.localizedDescription)")
        }
    }

    func forceSync() async {
        do {
            try await repository.sync(force: true)
            self.customers = sortedByRecent(try await repository.getCustomers())
        } catch {
            logger.error("Customers failed to load: \(error.localizedDescription)")
        }
    }

    private func sortedByRecent(_ list: [Customer]) -> [Customer] {
        list.filter { !$0.isDeleted }.sorted { ($0.lastPurchaseDate ?? $0.createdAt) > ($1.lastPurchaseDate ?? $1.createdAt) }
    }

    /// Generates a file containing the customer data and returns its temporary URL.
    public func export(format: FileFormat) throws -> URL {
        let fileString: String
        let fileName: String

        switch format {
        case .csv:
            fileString = customers.csvString
            fileName = "customers.csv"
        case .vcf:
            fileString = customers.vcfString
            fileName = "customers.vcf"
        }

        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        try fileString.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
