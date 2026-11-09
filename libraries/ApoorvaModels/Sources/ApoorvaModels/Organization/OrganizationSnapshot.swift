import Foundation

public struct OrganizationSnapshot: Codable, Sendable, Identifiable, Hashable {
    public var id: String { orgId }
    public let orgId: String
    public let name: String
    public let accentColor: String

    public enum CodingKeys: String, CodingKey {
        case orgId, name, accentColor
    }

    public init(orgId: String, name: String, accentColor: String = "#FF5733") {
        self.orgId = orgId
        self.name = name
        self.accentColor = accentColor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.orgId = try container.decode(String.self, forKey: .orgId)
        self.name = try container.decode(String.self, forKey: .name)
        self.accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor) ?? "#FF5733"
    }
}
