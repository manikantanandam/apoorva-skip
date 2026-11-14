//
//  CustomerPickerViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import Foundation
import ApoorvaModels
import ApoorvaRepository
import ManiLogger

private let logger = AppLogger(category: .ui)

/// Attach a customer to the bill (design 40): search, recent, or quick add.
@MainActor
@Observable
public class CustomerPickerViewModel {

    public var customers: [Customer] = []
    public var searchText: String = ""
    public var newPhone = ""
    public var newName = ""
    public var errorMessage: String?

    private let repository: CustomerRepositoryProtocol

    public init(repository: CustomerRepositoryProtocol) {
        self.repository = repository
    }

    public var filteredCustomers: [Customer] {
        guard !searchText.isEmpty else { return customers }
        return customers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || $0.phone.contains(searchText.filter(\.isNumber).isEmpty ? searchText : searchText.filter(\.isNumber))
        }
    }

    /// The three most recent buyers.
    public var recent: [Customer] {
        Array(customers.filter { $0.lastPurchaseDate != nil }
            .sorted { ($0.lastPurchaseDate ?? 0) > ($1.lastPurchaseDate ?? 0) }
            .prefix(3))
    }

    public var canAdd: Bool {
        newPhone.filter(\.isNumber).count == 10 && !newName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public func prepareData() async {
        do {
            self.customers = try await repository.getCustomers().sorted()
            logger.info("prepareData: loaded \(customers.count) customers from local storage, syncing")
            try await repository.sync(force: false)
            self.customers = try await repository.getCustomers().sorted()
            logger.info("prepareData: sync done, \(customers.count) customers, recent=\(recent.count)")
        } catch {
            logger.error("Customer picker failed to load: \(error.localizedDescription)")
        }
    }

    /// Saves a new customer (or returns the existing one with that phone).
    public func addCustomer() async -> Customer? {
        let phone = newPhone.filter(\.isNumber)
        guard canAdd else {
            logger.warning("addCustomer: blocked, form invalid (phoneDigits=\(phone.count))")
            return nil
        }
        if let existing = customers.first(where: { $0.phone == phone }) {
            logger.info("addCustomer: phone already exists, reusing customer \(existing.id)")
            return existing
        }
        let customer = Customer(name: newName.trimmingCharacters(in: .whitespaces), phone: phone,
                                createdAt: Date().timeIntervalSince1970, lastPurchaseDate: nil, totalSales: 0,
                                totalAmountSpent: 0, updatedAt: Date().timeIntervalSince1970, isDeleted: false)
        do {
            try await repository.saveCustomer(customer: customer)
            customers.append(customer)
            logger.info("addCustomer: saved new customer \(customer.id)")
            return customer
        } catch {
            logger.error("addCustomer: save failed: \(error.localizedDescription)")
            errorMessage = "Couldn't save the customer. Try again."
            return nil
        }
    }
}
