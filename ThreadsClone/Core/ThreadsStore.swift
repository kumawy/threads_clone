import Foundation
import Observation

@Observable
@MainActor
final class ThreadsStore {
    static let storageKey = "ThreadsClone.localState.v1"

    var currentUser: Person = SampleData.currentUser { didSet { persist() } }
    var posts: [ThreadPost] = SampleData.posts { didSet { persist() } }
    var people: [Person] = SampleData.people { didSet { persist() } }
    var followedIDs: Set<String> = SampleData.followedIDs { didSet { persist() } }
    var activities: [ActivityItem] = SampleData.activities { didSet { persist() } }
    var messages: [ChatMessage] = SampleData.messages { didSet { persist() } }
    var link = "" { didSet { persist() } }
    var isPrivate = false { didSet { persist() } }
    var notificationsEnabled = true { didSet { persist() } }
    var currentDate: Date = .now

    var profileName: String {
        get { currentUser.name }
        set { currentUser.name = newValue }
    }

    var bio: String {
        get { currentUser.bio }
        set { currentUser.bio = newValue }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isRestoring = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let state = try? JSONDecoder().decode(PersistedState.self, from: data),
           state.version == 1 {
            currentUser = state.currentUser
            posts = state.posts
            people = state.people
            followedIDs = state.followedIDs
            activities = state.activities
            messages = state.messages
            link = state.link
            isPrivate = state.isPrivate
            notificationsEnabled = state.notificationsEnabled
        }
        isRestoring = false
    }

    func person(id: String) -> Person {
        if id == currentUser.id { return currentUser }
        return people.first { $0.id == id }
            ?? Person(id: id, username: id, name: id, avatar: "avatar_\(id)")
    }

    func toggleFollow(_ id: String) {
        guard id != currentUser.id, people.contains(where: { $0.id == id }) else { return }
        if followedIDs.contains(id) {
            followedIDs.remove(id)
        } else {
            followedIDs.insert(id)
        }
    }

    func updateProfile(name: String, bio: String, link: String) {
        var updatedUser = currentUser
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { updatedUser.name = name }
        updatedUser.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        currentUser = updatedUser
        self.link = link.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func toggleLike(_ postID: String) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        var post = posts[index]
        post.isLiked.toggle()
        post.likes = max(0, post.likes + (post.isLiked ? 1 : -1))
        posts[index] = post
    }

    func toggleSave(_ postID: String) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].isSaved.toggle()
    }

    func toggleRepost(_ postID: String) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        var post = posts[index]
        post.isReposted.toggle()
        post.reposts = max(0, post.reposts + (post.isReposted ? 1 : -1))
        posts[index] = post
    }

    func isExpired(_ post: ThreadPost) -> Bool {
        post.isDisappearing && currentDate.timeIntervalSince(post.createdAt) >= 86_400
    }

    func refreshTime() {
        currentDate = .now
    }

    @discardableResult
    func publish(text: String, attachments: [String] = [], replyTo: String? = nil, isDisappearing: Bool = false, replyPermission: String = "Все") -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = attachments.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard text.count <= 500, !text.isEmpty || !attachments.isEmpty else { return false }
        var updatedPosts = posts
        if let parentID = replyTo {
            guard let index = updatedPosts.firstIndex(where: { $0.id == parentID }) else { return false }
            updatedPosts[index].replies += 1
        }
        updatedPosts.insert(
            ThreadPost(authorID: currentUser.id, text: text, images: attachments, replyToID: replyTo, isDisappearing: isDisappearing, replyPermission: replyPermission),
            at: 0
        )
        posts = updatedPosts
        return true
    }

    func messages(for personID: String) -> [ChatMessage] {
        messages.filter { $0.personID == personID }.sorted { $0.date < $1.date }
    }

    func sendMessage(_ text: String, to personID: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, personID != currentUser.id,
              people.contains(where: { $0.id == personID }) else { return }
        messages.append(ChatMessage(personID: personID, text: text, isOutgoing: true))
    }

    func markActivitiesRead() {
        activities = activities.map { item in
            var item = item
            item.isUnread = false
            return item
        }
    }

    private func persist() {
        guard !isRestoring else { return }
        let state = PersistedState(
            currentUser: currentUser, posts: posts, people: people, followedIDs: followedIDs,
            activities: activities, messages: messages, link: link,
            isPrivate: isPrivate, notificationsEnabled: notificationsEnabled
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private struct PersistedState: Codable {
        var version = 1
        var currentUser: Person
        var posts: [ThreadPost]
        var people: [Person]
        var followedIDs: Set<String>
        var activities: [ActivityItem]
        var messages: [ChatMessage]
        var link: String
        var isPrivate: Bool
        var notificationsEnabled: Bool
    }
}
