import Foundation

enum BillsRoute: Hashable {
    case detail(billId: String)
    case cancel(billId: String)
    case edit(billId: String)
    case receiptPreview(billId: String)
}
