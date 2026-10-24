
import Foundation
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class DailyCashFlowListViewModel {
    
    public var isLoading: Bool = false
    public var summaries: [DailyCashflowSummary] = []
    
    private let repository: DailyCashflowSummaryRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let organizationRepository: OrganizationRepositoryProtocol
    private let cashflowRepository: CashflowTransactionRepositoryProtocol
    
    public init(repository: DailyCashflowSummaryRepositoryProtocol,
                userRepository: UserRepositoryProtocol,
                organizationRepository: OrganizationRepositoryProtocol,
                cashflowRepository: CashflowTransactionRepositoryProtocol) {
        self.repository = repository
        self.cashflowRepository = cashflowRepository
        self.userRepository = userRepository
        self.organizationRepository = organizationRepository
    }
    
    // Renamed from fetchSummary to fetchData to reflect it grabs both
    public func fetchData() async { 
        do {
            isLoading = true
            
            summaries = try await repository.getDailyCashflowSummaries()
            isLoading = false
        } catch {
            print("Unable to fetch the daily cashflow summary \(error.localizedDescription)")
        }
    }

    func refreshData() async {
        do {
            try await repository.sync(force: true)
            await fetchData()
        } catch {
            print("Force sync failed \(error.localizedDescription)")
        }
        
    }
    
    func getAccounts() async throws -> [Account] {
        
        guard let orgId = try await getOrganizationId() else {
            return []
        }
        
        guard
            let fullOrganization = try await organizationRepository.getOrganization(
                orgId: orgId
            )
        else { return [] }
        
        return fullOrganization.accounts
    }
    
    func getOrganizationId() async throws -> String? {
        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else {
            return nil
        }
        
        return orgId
    }
    
    
}
