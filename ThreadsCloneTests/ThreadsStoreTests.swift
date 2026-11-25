import XCTest
@testable import ThreadsClone

@MainActor
final class ThreadsStoreTests: XCTestCase {
    private func withStore(_ body: (ThreadsStore, UserDefaults) throws -> Void) rethrows {
        let suite = "ThreadsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(ThreadsStore(defaults: defaults), defaults)
    }

    func testLikeTogglesAndRestoresOriginalCount() async throws {
        try withStore { store, _ in
            let post = try XCTUnwrap(store.posts.first)
            store.toggleLike(post.id)
            XCTAssertTrue(store.posts[0].isLiked)
            XCTAssertEqual(store.posts[0].likes, post.likes + 1)
            store.toggleLike(post.id)
            XCTAssertFalse(store.posts[0].isLiked)
            XCTAssertEqual(store.posts[0].likes, post.likes)
        }
    }

    func testRemovingLikeAndRepostNeverProducesNegativeCounts() async {
        withStore { store, _ in
            store.posts[0].likes = 0
            store.posts[0].isLiked = true
            store.posts[0].reposts = 0
            store.posts[0].isReposted = true
            let id = store.posts[0].id
            store.toggleLike(id)
            store.toggleRepost(id)
            XCTAssertEqual(store.posts[0].likes, 0)
            XCTAssertEqual(store.posts[0].reposts, 0)
            XCTAssertFalse(store.posts[0].isLiked)
            XCTAssertFalse(store.posts[0].isReposted)
        }
    }

    func testPublishRejectsBlankAndOverLimitTextWithoutChangingFeed() async {
        withStore { store, _ in
            let originalPosts = store.posts
            XCTAssertFalse(store.publish(text: " \n\t "))
            XCTAssertFalse(store.publish(text: String(repeating: "я", count: 501)))
            XCTAssertEqual(store.posts, originalPosts)
            XCTAssertTrue(store.publish(text: String(repeating: "я", count: 500)))
        }
    }

    func testPublishTrimsTextAndAddsCurrentUsersPostToFront() async throws {
        try withStore { store, _ in
            let earliestDate = Date()
            XCTAssertTrue(store.publish(text: "  Новая мысль\n "))
            let post = try XCTUnwrap(store.posts.first)
            XCTAssertEqual(post.text, "Новая мысль")
            XCTAssertEqual(post.authorID, "muratov")
            XCTAssertNil(post.replyToID)
            XCTAssertEqual(post.likes, 0)
            XCTAssertEqual(post.replies, 0)
            XCTAssertFalse(post.isLiked)
            XCTAssertGreaterThanOrEqual(post.createdAt, earliestDate)
            XCTAssertLessThanOrEqual(post.createdAt, Date())
        }
    }

    func testAttachmentOnlyPostIsAllowed() async throws {
        try withStore { store, _ in
            XCTAssertTrue(store.publish(text: " ", attachments: ["finance_expenses"]))
            let post = try XCTUnwrap(store.posts.first)
            XCTAssertEqual(post.text, "")
            XCTAssertEqual(post.images, ["finance_expenses"])
        }
    }

    func testDisappearingPostRetainsItsVisibilityModeAfterReload() async {
        withStore { store, defaults in
            XCTAssertTrue(store.publish(text: "На сегодня", isDisappearing: true))
            XCTAssertTrue(store.posts[0].isDisappearing)
            let reloaded = ThreadsStore(defaults: defaults)
            XCTAssertEqual(reloaded.posts[0].text, "На сегодня")
            XCTAssertTrue(reloaded.posts[0].isDisappearing)
        }
    }

    func testExistingSavedPostsWithoutDisappearingFlagDecodeAsPermanent() async throws {
        let original = ThreadPost(id: "existing", authorID: "muratov", text: "Сохранённая ветка")
        let encoded = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "isDisappearing")
        let olderData = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(ThreadPost.self, from: olderData)
        XCTAssertEqual(restored.text, "Сохранённая ветка")
        XCTAssertFalse(restored.isDisappearing)
    }

    func testExpirationStartsAtExactlyTwentyFourHoursAndOnlyForDisappearingPosts() async {
        withStore { store, _ in
            let createdAt = Date(timeIntervalSince1970: 1_000_000)
            let post = ThreadPost(authorID: "muratov", text: "На день", isDisappearing: true, createdAt: createdAt)
            store.currentDate = createdAt.addingTimeInterval(86_399.999)
            XCTAssertFalse(store.isExpired(post))
            store.currentDate = createdAt.addingTimeInterval(86_400)
            XCTAssertTrue(store.isExpired(post))
            store.currentDate = createdAt.addingTimeInterval(86_401)
            XCTAssertTrue(store.isExpired(post))
            var permanentPost = post
            permanentPost.isDisappearing = false
            XCTAssertFalse(store.isExpired(permanentPost))
            store.currentDate = createdAt.addingTimeInterval(-1)
            XCTAssertFalse(store.isExpired(post))
        }
    }

    func testRefreshingTimeAdvancesTheStoreClockToNow() async {
        withStore { store, _ in
            store.currentDate = Date(timeIntervalSince1970: 0)
            let earliestDate = Date()
            store.refreshTime()
            XCTAssertGreaterThanOrEqual(store.currentDate, earliestDate)
            XCTAssertLessThanOrEqual(store.currentDate, Date())
        }
    }

    func testReplyPermissionPersistsWithPublishedPost() async {
        withStore { store, defaults in
            XCTAssertTrue(store.publish(text: "Обсудим?", replyPermission: "Подписки"))
            XCTAssertEqual(store.posts[0].replyPermission, "Подписки")
            XCTAssertEqual(ThreadsStore(defaults: defaults).posts[0].replyPermission, "Подписки")
        }
    }

    func testExistingSavedPostsWithoutReplyPermissionAllowAllReplies() async throws {
        let original = ThreadPost(id: "existing", authorID: "muratov", text: "Ветка")
        let encoded = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "replyPermission")
        let olderData = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(ThreadPost.self, from: olderData)
        XCTAssertEqual(restored.replyPermission, "Все")
    }

    func testReplyKeepsParentIdentityAndIncrementsItsReplyCount() async throws {
        try withStore { store, _ in
            let parent = try XCTUnwrap(store.posts.first)
            XCTAssertTrue(store.publish(text: "Есть идея", replyTo: parent.id))
            let reply = try XCTUnwrap(store.posts.first)
            XCTAssertEqual(reply.replyToID, parent.id)
            XCTAssertEqual(reply.authorID, store.currentUser.id)
            XCTAssertEqual(store.posts.first { $0.id == parent.id }?.replies, parent.replies + 1)
            let postsBeforeInvalidReply = store.posts
            XCTAssertFalse(store.publish(text: "Ответ", replyTo: "missing-post"))
            XCTAssertEqual(store.posts, postsBeforeInvalidReply)
        }
    }

    func testSaveAndRepostAreReversibleAndUnknownIDsAreIgnored() async throws {
        try withStore { store, _ in
            let original = try XCTUnwrap(store.posts.first)
            store.toggleSave(original.id)
            store.toggleRepost(original.id)
            XCTAssertTrue(store.posts[0].isSaved)
            XCTAssertTrue(store.posts[0].isReposted)
            XCTAssertEqual(store.posts[0].reposts, original.reposts + 1)
            store.toggleSave(original.id)
            store.toggleRepost(original.id)
            XCTAssertEqual(store.posts[0], original)
            store.toggleLike("missing")
            store.toggleSave("missing")
            store.toggleRepost("missing")
            XCTAssertEqual(store.posts[0], original)
        }
    }

    func testFollowToggleIgnoresCurrentUserAndUnknownPeople() async {
        withStore { store, _ in
            store.followedIDs.remove("lizzi_znaet")
            store.toggleFollow("lizzi_znaet")
            XCTAssertTrue(store.followedIDs.contains("lizzi_znaet"))
            store.toggleFollow("lizzi_znaet")
            XCTAssertFalse(store.followedIDs.contains("lizzi_znaet"))
            let followedIDs = store.followedIDs
            store.toggleFollow(store.currentUser.id)
            store.toggleFollow("missing")
            XCTAssertEqual(store.followedIDs, followedIDs)
        }
    }

    func testMessagesTrimInputAndRemainInTheirConversation() async {
        withStore { store, _ in
            let originalCount = store.messages.count
            store.sendMessage(" \n ", to: "demianets")
            store.sendMessage("Привет", to: "missing")
            XCTAssertEqual(store.messages.count, originalCount)
            store.sendMessage("  Привет!  ", to: "demianets")
            XCTAssertEqual(store.messages.count, originalCount + 1)
            XCTAssertEqual(store.messages(for: "demianets").last?.text, "Привет!")
            XCTAssertEqual(store.messages(for: "demianets").last?.isOutgoing, true)
            XCTAssertFalse(store.messages(for: "lizzi_znaet").contains { $0.text == "Привет!" })
        }
    }

    func testChangesSurviveReloadIncludingProfileFollowMessagesAndSettings() async throws {
        try withStore { store, defaults in
            let postID = try XCTUnwrap(store.posts.first?.id)
            store.updateProfile(name: "  Aslan Updated  ", bio: " Новое описание ", link: " aslan.example ")
            store.toggleFollow("lizzi_znaet")
            store.toggleLike(postID)
            store.toggleSave(postID)
            store.toggleRepost(postID)
            XCTAssertTrue(store.publish(text: "Сохранённая ветка"))
            store.sendMessage("До встречи!", to: "demianets")
            store.isPrivate = true
            store.notificationsEnabled = false
            store.markActivitiesRead()

            let reloaded = ThreadsStore(defaults: defaults)
            XCTAssertEqual(reloaded.posts, store.posts)
            XCTAssertEqual(reloaded.currentUser.name, "Aslan Updated")
            XCTAssertEqual(reloaded.profileName, "Aslan Updated")
            XCTAssertEqual(reloaded.person(id: "muratov").bio, "Новое описание")
            XCTAssertEqual(reloaded.link, "aslan.example")
            XCTAssertEqual(reloaded.followedIDs, store.followedIDs)
            XCTAssertEqual(reloaded.messages, store.messages)
            XCTAssertTrue(reloaded.isPrivate)
            XCTAssertFalse(reloaded.notificationsEnabled)
            XCTAssertFalse(reloaded.activities.contains { $0.isUnread })
        }
    }

    func testMalformedPersistenceFallsBackToUsableSeedData() async {
        withStore { _, defaults in
            defaults.set(Data("{ broken JSON".utf8), forKey: ThreadsStore.storageKey)
            let recovered = ThreadsStore(defaults: defaults)
            XCTAssertEqual(recovered.currentUser.id, "muratov")
            XCTAssertFalse(recovered.posts.isEmpty)
            XCTAssertFalse(recovered.people.isEmpty)
            XCTAssertTrue(recovered.publish(text: "Всё работает"))
            XCTAssertEqual(ThreadsStore(defaults: defaults).posts.first?.text, "Всё работает")
        }
    }
}
