import Foundation

/// Customers are keyed by phone number (the SQLite primary key and Firestore doc ID).
enum CustomersRoute: Hashable, Identifiable {
    case detail(phone: String)
    case add
    case collect(phone: String)
    case reminder(phone: String)
    case statement(phone: String)

    var id: Self { self }
}
