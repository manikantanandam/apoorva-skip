//
//  File.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation
import ApoorvaServices

// In ApoorvaAppCore
@MainActor
public class ServicesContainer {
    // Lazy initialization ensures these are only created when needed
//    public lazy var offlineStorage: OfflineStorageProtocol = ApoorvaDataStore()
//    public lazy var apiClient: ApiClientProtocol = ApoorvaNetworkClient()
    
    public lazy var authService: AuthServicing = UITestingConfig.isEnabled ? FakeAuthService() : AuthService()
    
    public lazy var userService: UserServiceProtocol = {
        #if DEBUG
        if UITestingConfig.isSeedEnabled { return FakeUserService() }
        #endif
        return UserService(authService: authService)
    }()
    
    public lazy var inventoryService: InventoryItemServiceProtocol = InventoryItemService()
    
    public lazy var customerService: CustomerServiceProtocol = UITestingConfig.isEnabled ? NoOpCustomerService() : CustomerService()
    
    public lazy var saleService: SaleServiceProtocol = UITestingConfig.isEnabled ? NoOpSaleService() : SaleService()
    
    public lazy var cashflowService: CashflowTransactionServiceProtocol = CashflowTransactionService()
    
    public lazy var dailyCashflowService: DailyCashflowSummaryServiceProtocol = DailyCashflowSummaryService()
    
    public lazy var organizationService: OrganizationServiceProtocol = OrganizationService()

    public lazy var heldBillService: HeldBillServiceProtocol = UITestingConfig.isEnabled ? NoOpHeldBillService() : HeldBillService()

    public lazy var platformConfigService: PlatformConfigServicing = PlatformConfigService()

    public lazy var organizationSetupService: OrganizationSetupServicing = OrganizationSetupService()

    public lazy var pinStore: PinStoring = KeychainPinStore()

    public lazy var biometrics: BiometricAuthenticating = DeviceBiometrics()

    // Firebase isn't configured under `-UITesting`; Performance throws an uncaught NSException when a trace starts, so all three are no-ops there.
    public lazy var analyticsService: AnalyticsServicing = UITestingConfig.isEnabled ? NoOpAnalyticsService() : FirebaseAnalyticsService()

    public lazy var crashReportingService: CrashReportingServicing = UITestingConfig.isEnabled ? NoOpCrashReportingService() : FirebaseCrashReportingService()

    public lazy var performanceMonitoringService: PerformanceMonitoringServicing = UITestingConfig.isEnabled ? NoOpPerformanceMonitoringService() : FirebasePerformanceMonitoringService()

    public lazy var remoteConfigService: RemoteConfigServicing = {
        if UITestingConfig.isEnabled {
            let fake = FakeRemoteConfigService()
            fake.setDefaults(RemoteConfigCatalogDefaults.make())
            return fake
        }
        #if DEBUG
        // Debug builds always hit the network so console changes show up immediately.
        let service = FirebaseRemoteConfigService(minimumFetchInterval: 0)
        #else
        let service = FirebaseRemoteConfigService()
        #endif
        service.setDefaults(RemoteConfigCatalogDefaults.make())
        return service
    }()

    public init() {}
}
