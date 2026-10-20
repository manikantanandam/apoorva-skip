//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 15/10/26.
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

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

public enum CustomerSortOption: String, CaseIterable {
    case name = "Name"
    case phoneNumber = "Phone"
    case lastPurchaseDate = "Last Purchase Date"
    case createdAt = "Created Date"
}


@MainActor
@Observable
public class CustomerListViewModel {
    
    var customers: [Customer] = []
    
    let repository: CustomerRepositoryProtocol
    
    var sortOption: CustomerSortOption = .name {
        didSet {
            sortItems()
        }
    }
    
    
    public init(repository: CustomerRepositoryProtocol) {
        self.repository = repository
    }
    
    func prepareDate() async {
        do {
            self.customers = try await repository.getCustomers().sorted()
            try await repository.sync(force: false)
            self.customers = try await repository.getCustomers().sorted()
            
        } catch {
            print("Customer items failed \(error.localizedDescription)")
        }
    }
    
    func forceSync() async {
        do {
            try await repository.sync(force: true)
            self.customers = try await repository.getCustomers().sorted()
            
        } catch {
            print("Customer items failed \(error.localizedDescription)")
        }
    }
    
    func sortItems() {
            switch sortOption {
            case .name:
                customers.sort { $0.name > $1.name } // Uses the default Comparable conformance (<) from Customer
            case .phoneNumber:
                // Sorting descending by default to show highest stock first
                customers.sort { $0.phone > $1.phone }
            case .lastPurchaseDate:
                // Sorting descending to show most recently sold first. Nil dates go to the bottom.
                customers.sort {
                    let date1 = $0.lastPurchaseDate ?? 0
                    let date2 = $1.lastPurchaseDate ?? 0
                    return date1 > date2
                }
            case .createdAt:
                customers.sort {
                    let date1 = $0.createdAt
                    let date2 = $1.createdAt
                    return date1 > date2
                }
            }
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

