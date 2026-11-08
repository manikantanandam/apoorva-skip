import Foundation

enum BillsRoute: Hashable {
    case detail(billId: String)
    case cancel(billId: String)
}
