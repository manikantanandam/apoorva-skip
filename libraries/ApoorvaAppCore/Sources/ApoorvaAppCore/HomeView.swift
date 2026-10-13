import SwiftUI
import ApoorvaModules

enum HomeViewTab: Int, CaseIterable, Identifiable {
    case pos
    case profile
    case inventory
    case dashboard
    case reports
    case cashflow
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .pos: return "POS"
        case .dashboard: return "Dashboard"
        case .reports: return "Reports"
        case .cashflow: return "Cashflow"
        case .inventory: return "Inventory"
        case .profile: return "Profile"
        }
    }
    
    var systemImage: String {
            switch self {
            case .pos: return "cart.fill"
            case .dashboard: return "chart.bar.fill"
            case .reports: return "doc.text.fill"
            case .cashflow: return "dollarsign.circle.fill"
            case .inventory: return "cube.box.fill"
            case .profile: return "person.fill"
            }
        }
    
    @MainActor
    @ViewBuilder
    func viewContent(container: AppContainer) -> some View {
        switch self {
        case .pos:
            // Use the container to instantiate the POSViewModel
            POSView(viewModel: container.modulesContainer.makePOSViewModel())
        case .dashboard:
            Text("Dashboard Screen")
        case .reports:
            Text("Reports Screen")
        case .cashflow:
            Text("Cashflow Screen")
        case .inventory:
            InventoryView(viewModel: container.modulesContainer.makeInventoryViewModel())
        case .profile:
            ProfileView(viewModel: container.modulesContainer.makeProfileViewModel())
        }
    }
}

struct HomeView: View {
    @State private var selectedTab: HomeViewTab = .inventory
    
    // Pass or initialize your AppContainer here
    let container: AppContainer
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(HomeViewTab.allCases) { tab in
                NavigationStack {
                    tab.viewContent(container: container)
                        .font(.largeTitle)
                        .navigationTitle(tab.title)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .tint(.blue)
    }
}
