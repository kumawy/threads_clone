import Foundation

struct Person: Identifiable, Codable, Hashable {
    var id: String
    var username: String
    var name: String
    var avatar: String
    var bio: String = ""
    var followers: Int = 0
    var isVerified: Bool = false
}

struct ThreadPost: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var authorID: String
    var text: String
    var timestamp: String = "только что"
    var likes: Int = 0
    var replies: Int = 0
    var reposts: Int = 0
    var isLiked: Bool = false
    var isSaved: Bool = false
    var isReposted: Bool = false
    var images: [String] = []
    var replyToID: String? = nil
    var isDisappearing: Bool = false
    var replyPermission: String = "Все"
    var createdAt: Date = Date()
}

extension ThreadPost {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        authorID = try values.decode(String.self, forKey: .authorID)
        text = try values.decode(String.self, forKey: .text)
        timestamp = try values.decode(String.self, forKey: .timestamp)
        likes = try values.decode(Int.self, forKey: .likes)
        replies = try values.decode(Int.self, forKey: .replies)
        reposts = try values.decode(Int.self, forKey: .reposts)
        isLiked = try values.decode(Bool.self, forKey: .isLiked)
        isSaved = try values.decode(Bool.self, forKey: .isSaved)
        isReposted = try values.decode(Bool.self, forKey: .isReposted)
        images = try values.decode([String].self, forKey: .images)
        replyToID = try values.decodeIfPresent(String.self, forKey: .replyToID)
        isDisappearing = try values.decodeIfPresent(Bool.self, forKey: .isDisappearing) ?? false
        replyPermission = try values.decodeIfPresent(String.self, forKey: .replyPermission) ?? "Все"
        createdAt = try values.decode(Date.self, forKey: .createdAt)
    }
}

enum ActivityKind: String, Codable, CaseIterable {
    case following, reply, mention, like
}

struct ActivityItem: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var personID: String
    var kind: ActivityKind
    var text: String
    var time: String
    var isUnread: Bool = true
}

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var personID: String
    var text: String
    var isOutgoing: Bool
    var date: Date = Date()
}
