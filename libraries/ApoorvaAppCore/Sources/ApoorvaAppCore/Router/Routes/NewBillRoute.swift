import Foundation

enum NewBillRoute: Hashable, Identifiable {
    case customerPicker
    /// Edit an existing bill line (design 33).
    case lineEdit(lineId: String)
    /// Add an item that has no price on file yet (design 33, new line).
    case newLine(itemId: String)
    case checkout
    case split
    case upiQR
    case receipt(saleId: String)
    case receiptPreview(saleId: String)
    case held
    case returnExchange(billId: String)
    case scan
    case jewelItem(itemId: String)
    case catalogShare
    case parlourPackages

    var id: Self { self }
}

/// Bottom sheets over the POS screen (designs 27, 28, 32, 34). Price tier (41) is inline.
enum NewBillSheet: Hashable, Identifiable {
    case weight(itemId: String)
    case customItem
    case variant(itemId: String)
    case discount
    /// Quick-grid layout half sheets.
    case find
    case quickAdd(itemId: String)
    case quickEdit(lineId: String)

    var id: Self { self }

    /// Quick-grid sheets open at half height like the production app; the rest stay full height.
    var isHalfSheet: Bool {
        switch self {
        case .find, .quickAdd, .quickEdit: true
        case .weight, .customItem, .variant, .discount: false
        }
    }
}
