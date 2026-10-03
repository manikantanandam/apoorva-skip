import Foundation

public struct AppUserSnapshot: Codable, Sendable {
    public let uid: String
    public let name: String
    public let email: String
    public let orgRole: String
    
    public enum CodingKeys: String, CodingKey {
        case uid, name, email, orgRole
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uid = try container.decode(String.self, forKey: .uid)
        self.name = try container.decode(String.self, forKey: .name)
        self.email = try container.decode(String.self, forKey: .email)
        self.orgRole = try container.decodeIfPresent(String.self, forKey: .orgRole) ?? "staff"
    }
}

public struct AppUser: Codable, Sendable {
    public let id: String
    public let name: String
    public let email: String
    public let role: AppUserRole
    public let status: String
    public let assignedOrgs: [OrganizationSnapshot]
    public let createdAt: Date
    
    public var updatedAt: Date
    public var isDeleted: Bool
    
    public enum CodingKeys: String, CodingKey {
        case id, name, email, role, status, assignedOrgs, createdAt, updatedAt, isDeleted
    }
    
    public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
            self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "Unknown User"
            self.email = (try? container.decodeIfPresent(String.self, forKey: .email)) ?? ""
            self.role = (try? container.decodeIfPresent(AppUserRole.self, forKey: .role)) ?? .standard
            self.status = (try? container.decodeIfPresent(String.self, forKey: .status)) ?? "Active"
            self.assignedOrgs = (try? container.decodeIfPresent([OrganizationSnapshot].self, forKey: .assignedOrgs)) ?? []
            
            // --- BULLETPROOF DATE DECODING ---
            if let standardDate = try? container.decodeIfPresent(Date.self, forKey: .createdAt) {
                // 1. Success: It was a true Firestore Timestamp
                self.createdAt = standardDate
            } else if let dateString = try? container.decodeIfPresent(String.self, forKey: .createdAt) {
                // 2. Fallback: It was saved as a String (like your screenshot)
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                
                // Matches: "31 March 2026 at 19:53:12 UTC+05:30"
                formatter.dateFormat = "dd MMMM yyyy 'at' HH:mm:ss 'UTC'ZZZZZ"
                
                // Fix the missing leading zero in the timezone for safe parsing
                let cleanString = dateString.replacingOccurrences(of: "UTC+5:", with: "UTC+05:")
                
                self.createdAt = formatter.date(from: cleanString) ?? Date()
            } else {
                // 3. Absolute fallback
                self.createdAt = Date()
            }
            
            self.updatedAt = (try? container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? Date()
            self.isDeleted = (try? container.decodeIfPresent(Bool.self, forKey: .isDeleted)) ?? false
        }
    
    public init(id: String, name: String, email: String, role: AppUserRole, status: String, assignedOrgs: [OrganizationSnapshot], createdAt: Date, updatedAt: Date = Date(), isDeleted: Bool = false) {
            self.id = id
            self.name = name
            self.email = email
            self.role = role
            self.status = status
            self.assignedOrgs = assignedOrgs
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
        }
}
