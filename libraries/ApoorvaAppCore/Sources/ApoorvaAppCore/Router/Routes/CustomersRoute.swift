import Foundation

/// Customers are keyed by phone number (the SQLite primary key and Firestore doc ID).
enum CustomersRoute: Hashable, Identifiable {
    case detail(phone: String)
    case add
    case edit(phone: String)
    case collect(phone: String)
    case reminder(phone: String)
    case statement(phone: String)
    case importContacts
    case offers

    var id: Self { self }
}
