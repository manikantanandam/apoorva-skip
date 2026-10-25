import ApoorvaModels
import GRDB
import Foundation

extension AppUserRole: @retroactive DatabaseValueConvertible {}

extension AppUser: @retroactive FetchableRecord, @retroactive MutablePersistableRecord, DatabaseMigratable {
    public static let databaseTableName = "AppUser"
    
    public static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("email", .text).notNull()
            t.column("role", .text).notNull()
            t.column("status", .text).notNull()
            t.column("assignedOrgs", .text).notNull()
            t.column("createdAt", .datetime).notNull()
            
            t.column("updatedAt", .datetime).notNull()
            t.column("isDeleted", .boolean).notNull().defaults(to: false)
        }
    }
    
    public init(row: Row) throws {
        let decoder = JSONDecoder()
        let orgsString: String = row["assignedOrgs"]
        let decodedOrgs = try decoder.decode([OrganizationSnapshot].self, from: Data(orgsString.utf8))
        
        self.init(
            id: row["id"],
            name: row["name"],
            email: row["email"],
            role: row["role"],
            status: row["status"],
            assignedOrgs: decodedOrgs,
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"],
            isDeleted: row["isDeleted"]
        )
    }
    
    public func encode(to container: inout PersistenceContainer) throws {
        let encoder = JSONEncoder()
        container["id"] = id
        container["name"] = name
        container["email"] = email
        container["role"] = role
        container["status"] = status
        container["assignedOrgs"] = try String(data: encoder.encode(assignedOrgs), encoding: .utf8)
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
        container["isDeleted"] = isDeleted
    }
}
