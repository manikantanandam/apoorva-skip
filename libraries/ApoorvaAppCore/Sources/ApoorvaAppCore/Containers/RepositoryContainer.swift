//
//  RepositoryContainer.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaServices
import ApoorvaRepository
import ApoorvaModels
import ApoorvaOfflineStorage

// In ApoorvaAppCore
@MainActor
public class RepositoryContainer {
    private let servicesContainer: ServicesContainer
    private let offlineStorageContainer: OfflineStorageContainer
    
    public init(servicesContainer: ServicesContainer,
                offlineStorageContainer: OfflineStorageContainer) {
        self.servicesContainer = servicesContainer
        self.offlineStorageContainer = offlineStorageContainer
    }
    
    public lazy var userRepository = UserRepository(
        userDefaults: offlineStorageContainer.userDefaultsStorage,
        authService: servicesContainer.authService,
        userService: servicesContainer.userService
    )
    
    public lazy var inventoryRepository: InventoryItemRepositoryProtocol = InventoryItemRepository(
        storage: offlineStorageContainer.inventoryItemsLocalStorage,
        service: servicesContainer.inventoryService,
        userRepository: userRepository,
        syncStorage: offlineStorageContainer.syncStorage
    )
    
    public lazy var customerRepository: CustomerRepositoryProtocol = CustomerRepository(
        storage: offlineStorageContainer.customersLocalStorage,
        service: servicesContainer.customerService,
        userRepository: userRepository,
        syncStorage: offlineStorageContainer.syncStorage
    )
    
    public lazy var heldBillRepository: HeldBillRepositoryProtocol = HeldBillRepository(
        storage: offlineStorageContainer.heldBillsLocalStorage,
        service: servicesContainer.heldBillService,
        userRepository: userRepository,
        syncStorage: offlineStorageContainer.syncStorage
    )

    public lazy var saleRepository: SaleRepositoryProtocol = SaleRepository(
        storage: offlineStorageContainer.salesLocalStorage,
        service: servicesContainer.saleService,
        customerService: servicesContainer.customerService,
        heldBillRepository: heldBillRepository,
        userRepository: userRepository,
        syncStorage: offlineStorageContainer.syncStorage
    )
    
    public lazy var cashflowRepository: CashflowTransactionRepositoryProtocol = CashflowTransactionRepository(
        storage: offlineStorageContainer.cashflowLocalStorage,
        service: servicesContainer.cashflowService,
        userRepository: userRepository,
        syncStorage: offlineStorageContainer.syncStorage
    )
    
    public lazy var dailyCashflowRepository: DailyCashflowSummaryRepositoryProtocol = DailyCashflowSummaryRepository(
        storage: offlineStorageContainer.dailyCashflowStorage,
        service: servicesContainer.dailyCashflowService,
        userRepository: userRepository,
        syncStorage: offlineStorageContainer.syncStorage
    )
    
    public lazy var organizationRepository: OrganizationRepositoryProtocol = OrganizationRepository(
        storage: offlineStorageContainer.organizationStorage,
        service: servicesContainer.organizationService,
        userRepository: userRepository,
        syncStorage: offlineStorageContainer.syncStorage
    )

    // MARK: - Org collections (local-first, synced under organizations/{orgId}/...)

    public lazy var orgContext: OrgContextProviding = UserRepositoryOrgContext(userRepository: userRepository)

    /// Builds a repository for any `OrgDocument` collection, sharing the local DB and sync cursors.
    public func makeOrgCollectionRepository<Document: OrgDocument>(_ type: Document.Type) -> OrgCollectionRepository<Document> {
        OrgCollectionRepository<Document>(
            storage: OrgCollectionLocalStorage(database: offlineStorageContainer.skipSqlDatabase),
            service: OrgCollectionService(),
            context: orgContext,
            syncStorage: offlineStorageContainer.syncStorage
        )
    }

    public lazy var auditRepository = makeOrgCollectionRepository(AuditEvent.self)
    public lazy var customerLedgerRepository = makeOrgCollectionRepository(CustomerLedgerEntry.self)
    public lazy var stockMovementRepository = makeOrgCollectionRepository(StockMovement.self)
    public lazy var auditLogger: AuditLogging = AuditLogger(repository: auditRepository, context: orgContext)
    public lazy var settingsRepository = makeOrgCollectionRepository(OrgSettings.self)
    public lazy var storeRepository = makeOrgCollectionRepository(Store.self)
    public lazy var memberRepository = makeOrgCollectionRepository(Member.self)
    public lazy var supplierRepository = makeOrgCollectionRepository(Supplier.self)
    public lazy var servicePackageRepository = makeOrgCollectionRepository(ServicePackage.self)
    public lazy var customerPackageRepository = makeOrgCollectionRepository(CustomerPackage.self)

    /// Keeps a bill's stock, dues and audit trail consistent across save / cancel / undo / edit.
    public lazy var saleLifecycleRepository: SaleLifecycleRepositoryProtocol = SaleLifecycleRepository(
        saleRepository: saleRepository,
        inventoryRepository: inventoryRepository,
        customerRepository: customerRepository,
        stockMovements: stockMovementRepository,
        ledger: customerLedgerRepository,
        audit: auditLogger
    )

    /// Pulls every collection down. Call on sign-in, on foreground, and on pull-to-refresh.
    public lazy var syncEngine: SyncEngine = {
        let inventory = inventoryRepository
        let customers = customerRepository
        let sales = saleRepository
        let heldBills = heldBillRepository
        let cashflow = cashflowRepository
        let dailyCashflow = dailyCashflowRepository
        return SyncEngine(repositories: [
            SyncAdapter("inventory") { try await inventory.sync(force: $0) },
            SyncAdapter("customers") { try await customers.sync(force: $0) },
            SyncAdapter("sales") { try await sales.sync(force: $0) },
            SyncAdapter("heldBills") { try await heldBills.sync(force: $0) },
            SyncAdapter("cashflow") { try await cashflow.sync(force: $0) },
            SyncAdapter("dailyCashflowSummaries") { try await dailyCashflow.sync(force: $0) },
            settingsRepository,
            storeRepository,
            memberRepository,
            supplierRepository,
            servicePackageRepository,
            customerPackageRepository,
            customerLedgerRepository,
            stockMovementRepository,
            auditRepository
        ])
    }()

    /// Clears all local SQLite tables and the cached-user UserDefaults keys, in place, no restart needed.
    public func clearLocalData() throws {
        try offlineStorageContainer.skipSqlDatabase.clearAllLocalData()
        offlineStorageContainer.userDefaultsStorage.removeAll(matchingPrefix: "user_")
    }
}
