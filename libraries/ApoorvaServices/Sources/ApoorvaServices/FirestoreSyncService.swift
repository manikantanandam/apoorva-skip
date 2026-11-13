import FirebaseFirestore
import ApoorvaModels
import Foundation
import ApoorvaLogging

private let logger = AppLogger(category: .network)

public typealias Category = ApoorvaModels.InventoryItem
public final class FirestoreSyncService: @unchecked Sendable {
    private let db = Firestore.firestore()
    
    public init() {}
    
    public func fetchSaleDeltas(for orgId: String, since lastSync: Date?) async throws -> [Sale] {
            var query: Query = db.collection("organizations").document(orgId).collection("sales")
            
            if let lastSync = lastSync {
                // 👉 FIX: Change "updatedAt" to "timestamp" so it matches your Sale model
                query = query.whereField("timestamp", isGreaterThan: Timestamp(date: lastSync))
            }
            
            logger.debug("Fetching Sale deltas for Org: \(orgId)")
            let snapshot = try await query.getDocuments()
            
            var successfulSales: [Sale] = []
            for document in snapshot.documents {
                do {
                    let sale = try document.data(as: Sale.self)
                    successfulSales.append(sale)
                } catch {
                    logger.error("Failed to decode Sale: \(document.documentID) - \(error)")
                }
            }
            return successfulSales
        }
    
    // Fetch Customers
        public func fetchCustomerDeltas(for orgId: String, since lastSync: Date?) async throws -> [Customer] {
            var query: Query = db.collection("organizations").document(orgId).collection("customers")
            if let lastSync = lastSync {
                query = query.whereField("updatedAt", isGreaterThan: Timestamp(date: lastSync))
            }
            
            let snapshot = try await query.getDocuments()
            var successfulRecords: [Customer] = []
            
            for document in snapshot.documents {
                do {
                    let record = try document.data(as: Customer.self)
                    successfulRecords.append(record)
                } catch { logger.error("Failed to decode Customer:\(document.documentID) - \(error)") }
            }
            return successfulRecords
        }
        
        // Fetch Inventory
    public func fetchInventoryDeltas(for orgId: String, since lastSync: Date?) async throws -> [Category] {
            var query: Query = db.collection("organizations").document(orgId).collection("inventory")
            if let lastSync = lastSync {
                query = query.whereField("updatedAt", isGreaterThan: Timestamp(date: lastSync))
            }
            
            let snapshot = try await query.getDocuments()
            var successfulRecords: [Category] = []
            
            for document in snapshot.documents {
                do {
                    let record = try document.data(as: Category.self)
                    successfulRecords.append(record)
                } catch { logger.error("Failed to decode Inventory:\(document.documentID) - \(error)") }
            }
            return successfulRecords
        }
    
    public func fetchCategoryDeltas(for orgId: String, since lastSync: Date?) async throws -> [Category] {
            // NOTE: We are targeting the "inventory" collection in Firebase, but decoding it as our Swift Category model
            var query: Query = db.collection("organizations").document(orgId).collection("inventory")
            
            if let lastSync = lastSync {
                query = query.whereField("updatedAt", isGreaterThan: Timestamp(date: lastSync))
            }
            
            logger.debug("Fetching Categories for Org: \(orgId)")
            let snapshot = try await query.getDocuments()
            
            var successfulRecords: [Category] = []
            for document in snapshot.documents {
                do {
                    var record = try document.data(as: Category.self)
                    if record.id.isEmpty { record.id = document.documentID } // Inject ID safely
                    successfulRecords.append(record)
                } catch { logger.error("Failed to decode Category:\(document.documentID) - \(error)") }
            }
            
            logger.info("Fetched \(successfulRecords.count) Categories")
            return successfulRecords
        }
    
    // MARK: - Cashflow Services
        
        public func fetchCashflowDeltas(for orgId: String, since lastSync: Date?) async throws -> [CashflowTransaction] {
            var query: Query = db.collection("organizations").document(orgId).collection("cashflow")
            
            if let lastSync = lastSync {
                query = query.whereField("updatedAt", isGreaterThan: Timestamp(date: lastSync))
            }
            
            logger.debug("Fetching Cashflow deltas for Org: \(orgId)")
            let snapshot = try await query.getDocuments()
            
            var successfulRecords: [CashflowTransaction] = []
            for document in snapshot.documents {
                do {
                    let record = try document.data(as: CashflowTransaction.self)
                    successfulRecords.append(record)
                } catch {
                    logger.error("Failed to decode Cashflow:\(document.documentID) - \(error)")
                }
            }
            
            logger.info("Fetched \(successfulRecords.count) Cashflow records")
            return successfulRecords
        }
        
        public func pushCashflowTransaction(_ transaction: CashflowTransaction, for orgId: String) async throws {
            logger.debug("Pushing Cashflow Transaction \(transaction.id)")
            
            let docRef = db.collection("organizations").document(orgId).collection("cashflow").document(transaction.id)
            
            // Encodes the Swift struct into Firestore JSON and uploads it
            try docRef.setData(from: transaction)
            logger.info("Pushed Cashflow Transaction \(transaction.id)")
        }
}
