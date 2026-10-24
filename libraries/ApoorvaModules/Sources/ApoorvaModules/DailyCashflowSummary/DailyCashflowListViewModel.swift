import Foundation
import ApoorvaModels
import ApoorvaRepository

public enum DailyCashflowSortOption: String, CaseIterable {
    case newest = "Newest"
    case oldest = "Oldest"
}

public enum DailyCashflowDateFilterOption: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case last7Days = "Last 7 Days"
    case thisMonth = "This Month"
    case last3Months = "Last 3 Months"
    case thisYear = "This Year"
    case custom = "Custom"
}

@MainActor
@Observable
public class DailyCashFlowListViewModel {
    
    public var isLoading: Bool = false
    public var summaries: [DailyCashflowSummary] = []
    
    // Dashboard Stats
    public var shopSetupTotal: Double = 0.0
    public var totalIncome: Double = 0.0
    public var totalExpense: Double = 0.0
    public var inventoryTotal: Double = 0.0
    public var profitOrLoss: Double = 0.0
    
    // Backing store containing all dates from established to today
    private var allSummaries: [DailyCashflowSummary] = []
    
    private let repository: DailyCashflowSummaryRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let organizationRepository: OrganizationRepositoryProtocol
    private let cashflowRepository: CashflowTransactionRepositoryProtocol
    
    // Filtering & Sorting State
    var sortOption: DailyCashflowSortOption = .newest {
        didSet { sortItems() }
    }
    
    var dateFilter: DailyCashflowDateFilterOption = .all {
        didSet { applyFilterAndSort() }
    }
    
    var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date() {
        didSet { if dateFilter == .custom { applyFilterAndSort() } }
    }
    
    var customEndDate: Date = Date() {
        didSet { if dateFilter == .custom { applyFilterAndSort() } }
    }
    
    public init(repository: DailyCashflowSummaryRepositoryProtocol,
                userRepository: UserRepositoryProtocol,
                organizationRepository: OrganizationRepositoryProtocol,
                cashflowRepository: CashflowTransactionRepositoryProtocol) {
        self.repository = repository
        self.cashflowRepository = cashflowRepository
        self.userRepository = userRepository
        self.organizationRepository = organizationRepository
    }
    
    public func fetchData() async {
        do {
            isLoading = true
            
            // Fetch Summaries
            let fetchedSummaries = try await repository.getDailyCashflowSummaries()
            try await prepareDates(with: fetchedSummaries)
            
            // Sync & Refetch
            try await repository.sync(force: false)
            
            let updatedSummaries = try await repository.getDailyCashflowSummaries()
            try await prepareDates(with: updatedSummaries)
            
            // Fetch Transactions for Dashboard
            let transactions = try await cashflowRepository.getCashflowTransactions()
            calculateDashboardStats(from: transactions)
            
            isLoading = false
        } catch {
            print("Unable to fetch the daily cashflow summary \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    private func calculateDashboardStats(from transactions: [CashflowTransaction]) {
        var setup: Double = 0
        var income: Double = 0
        var expense: Double = 0
        var inventory: Double = 0

        for t in transactions {
            // Ignore internal transfers and deleted records[cite: 9, 11]
            if t.category == .internalTransfer || t.isDeleted { continue }
            
            // Categorized sums[cite: 9]
            if t.category == .shopSetup {
                setup += t.amount
            } else if t.category == .inventory {
                inventory += t.amount
            }
            
            // General Cashflow[cite: 11]
            if t.transactionType == .credit {
                income += t.amount
            } else if t.transactionType == .debit {
                expense += t.amount
            }
        }
        
        self.shopSetupTotal = setup
        self.inventoryTotal = inventory
        self.totalIncome = income
        self.totalExpense = expense
        self.profitOrLoss = income - expense
    }
    
    func prepareDates(with fetchedSummaries: [DailyCashflowSummary]) async throws {
        guard let orgId = try await getOrganizationId() else { return }
        guard let fullOrganization = try await organizationRepository.getOrganization(orgId: orgId) else { return }
        let establishedAtInMsDate = fullOrganization.establishedAtInMs.date
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: establishedAtInMsDate)
        let endDate = calendar.startOfDay(for: Date())
        
        var allDates: [Date] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            allDates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        let existingSummaries = Dictionary(fetchedSummaries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var fullList: [DailyCashflowSummary] = []
        
        for date in allDates {
            let id = date.toString(format: "dd-MM-yyyy")
            if let existing = existingSummaries[id] {
                fullList.append(existing)
            } else {
                let emptySummary = DailyCashflowSummary(
                    date: date,
                    openingBalances: [],
                    closingBalances: [],
                    updatedAt: Date().timeIntervalSince1970,
                    locked: false
                )
                fullList.append(emptySummary)
            }
        }
        
        self.allSummaries = fullList
        applyFilterAndSort()
    }
    
    private func applyFilterAndSort() {
        let calendar = Calendar.current
        let now = Date()
        
        let filtered = allSummaries.filter { item in
            var dateMatches = false
            switch dateFilter {
            case .today: dateMatches = calendar.isDateInToday(item.date)
            case .last7Days:
                if let pastDate = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) {
                    dateMatches = item.date >= pastDate
                } else { dateMatches = true }
            case .thisMonth: dateMatches = calendar.isDate(item.date, equalTo: now, toGranularity: .month)
            case .last3Months:
                if let pastDate = calendar.date(byAdding: .month, value: -3, to: now) {
                    dateMatches = item.date >= pastDate
                } else { dateMatches = true }
            case .thisYear: dateMatches = calendar.isDate(item.date, equalTo: now, toGranularity: .year)
            case .all: dateMatches = true
            case .custom:
                let startOfDay = calendar.startOfDay(for: customStartDate)
                let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
                dateMatches = item.date >= startOfDay && item.date <= endOfDay
            }
            return dateMatches
        }
        
        self.summaries = filtered
        sortItems()
    }
    
    private func sortItems() {
        switch sortOption {
        case .newest: self.summaries.sort { $0.date > $1.date }
        case .oldest: self.summaries.sort { $0.date < $1.date }
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
    
    func getOrganizationId() async throws -> String? {
        let user = try await userRepository.getCurrentUser()
        return user.selectedOrganization?.orgId
    }
}
