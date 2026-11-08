import Foundation

enum CustomersRoute: Hashable, Identifiable {
    case detail(customerId: String)
    case add
    case collect(customerId: String)
    case reminder(customerId: String)
    case statement(customerId: String)

    var id: Self { self }
}
