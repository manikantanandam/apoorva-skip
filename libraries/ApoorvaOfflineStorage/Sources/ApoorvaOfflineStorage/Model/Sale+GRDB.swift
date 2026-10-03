import ApoorvaModels
import GRDB
import Foundation

extension Sale: @retroactive FetchableRecord, @retroactive MutablePersistableRecord, DatabaseMigratable {
    public static let databaseTableName = "Sale"

    public static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.column("id", .text).primaryKey()
            t.column("staffId", .text).notNull()
            t.column("customerPhone", .text).indexed()
            t.column("customerName", .text).notNull()
            t.column("items", .text).notNull()
            t.column("subtotal", .double).notNull()
            t.column("overallDiscountPercent", .double).notNull()
            t.column("overallDiscountAmount", .double).notNull()
            t.column("roundOff", .double).notNull()
            t.column("netPayable", .double).notNull()
            t.column("payments", .text).notNull()
            t.column("timestamp", .datetime).notNull()
            t.column("source", .text).notNull()
            t.column("status", .text).notNull()
            t.column("whatsappStatus", .text).notNull()
            
            t.column("updatedAt", .datetime).notNull() // Using .notNull() in DB because SQLite handles Date? well if mapped carefully, but ensure your schema handles nulls if needed.
            t.column("isDeleted", .boolean).notNull().defaults(to: false)
        }
    }
    
    public init(row: Row) throws {
        let decoder = JSONDecoder()
        
        let itemsString: String = row["items"]
        let decodedItems = try decoder.decode([SaleItem].self, from: Data(itemsString.utf8))
        
        let paymentsString: String = row["payments"]
        let decodedPayments = try decoder.decode([PaymentMode: Double].self, from: Data(paymentsString.utf8))
        
        self.init(
            id: row["id"],
            staffId: row["staffId"],
            customerPhone: row["customerPhone"],
            customerName: row["customerName"],
            items: decodedItems,
            subtotal: row["subtotal"],
            overallDiscountPercent: row["overallDiscountPercent"],
            overallDiscountAmount: row["overallDiscountAmount"],
            roundOff: row["roundOff"],
            netPayable: row["netPayable"],
            payments: decodedPayments,
            timestamp: row["timestamp"],
            source: row["source"],
            status: row["status"],
            whatsappStatus: row["whatsappStatus"],
            updatedAt: row["updatedAt"],
            isDeleted: row["isDeleted"]
        )
    }
    
    public func encode(to container: inout PersistenceContainer) throws {
        let encoder = JSONEncoder()
        container["id"] = id
        container["staffId"] = staffId
        container["customerPhone"] = customerPhone
        container["customerName"] = customerName
        container["items"] = try String(data: encoder.encode(items), encoding: .utf8)
        container["subtotal"] = subtotal
        container["overallDiscountPercent"] = overallDiscountPercent
        container["overallDiscountAmount"] = overallDiscountAmount
        container["roundOff"] = roundOff
        container["netPayable"] = netPayable
        container["payments"] = try String(data: encoder.encode(payments), encoding: .utf8)
        container["timestamp"] = timestamp
        container["source"] = source
        container["status"] = status
        container["whatsappStatus"] = whatsappStatus
        container["updatedAt"] = updatedAt
        container["isDeleted"] = isDeleted
    }
}
