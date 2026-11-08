//
//  CustomerPickerViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class CustomerPickerViewModel {

    public var customers: [Customer] = []
    public var searchText: String = ""

    private let repository: CustomerRepositoryProtocol

    public init(repository: CustomerRepositoryProtocol) {
        self.repository = repository
    }

    public var filteredCustomers: [Customer] {
        guard !searchText.isEmpty else { return customers }
        return customers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || $0.phone.contains(searchText)
        }
    }

    public func prepareData() async {
        do {
            self.customers = try await repository.getCustomers().sorted()
            try await repository.sync(force: false)
            self.customers = try await repository.getCustomers().sorted()
        } catch {
            print("Customer picker failed to load \(error.localizedDescription)")
        }
    }
}
