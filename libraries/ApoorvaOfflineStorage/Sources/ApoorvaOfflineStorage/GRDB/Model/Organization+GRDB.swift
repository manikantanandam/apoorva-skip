import ApoorvaModels
import GRDB
import Foundation

extension Organization: @retroactive FetchableRecord, @retroactive MutablePersistableRecord, DatabaseMigratable {
    public static let databaseTableName = "Organization"
    
    public static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("status", .text).notNull()
            t.column("createdAt", .datetime).notNull()
            t.column("minVersion", .text).notNull()
            t.column("currentTheme", .text).notNull()
            t.column("accentColor", .text).notNull()
            t.column("accounts", .text).notNull() // JSON Array
            
            t.column("updatedAt", .datetime).notNull()
            t.column("isDeleted", .boolean).notNull().defaults(to: false)
        }
    }

    public init(row: Row) throws {
            let decoder = JSONDecoder()
            
            let accountsString: String = row["accounts"]
            let decodedAccounts = try decoder.decode([Account].self, from: Data(accountsString.utf8))
            
            self.init(
                id: row["id"],
                name: row["name"],
                status: row["status"],
                createdAt: row["createdAt"],
                minVersion: row["minVersion"],
                currentTheme: row["currentTheme"],
                accentColor: row["accentColor"],
                accounts: decodedAccounts,
                updatedAt: row["updatedAt"],
                isDeleted: row["isDeleted"]
            )
        }
}
