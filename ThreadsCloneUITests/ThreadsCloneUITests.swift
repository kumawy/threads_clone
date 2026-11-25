import XCTest

final class ThreadsCloneUITests: XCTestCase {
    @MainActor
    func test01ReferenceScreens() throws {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Главная"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.buttons.allElementsBoundByIndex.map(\.label), ["Главная", "Сообщения", "Новая ветка", "Действия", "Профиль"])
        capture("01-Home")
        app.tabBars.buttons["Сообщения"].tap()
        XCTAssertTrue(app.staticTexts["Сообщения"].firstMatch.waitForExistence(timeout: 5))
        capture("02-Messages")
        app.tabBars.buttons["Действия"].tap()
        XCTAssertTrue(app.staticTexts["Действия"].firstMatch.waitForExistence(timeout: 5))
        capture("03-Activity")
        app.tabBars.buttons["Профиль"].tap()
        XCTAssertTrue(app.staticTexts["Aslan"].firstMatch.waitForExistence(timeout: 5))
        capture("04-Profile")
        app.buttons["Настройки"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Настройки"].firstMatch.waitForExistence(timeout: 5))
        capture("05-Settings")
    }

    @MainActor
    func test02PublishingLikeAndPersistence() throws {
        let app = makeApp()
        app.launch()
        let like = app.buttons["like_post-lizzi-claude"]
        XCTAssertTrue(like.waitForExistence(timeout: 10))
        like.tap()
        XCTAssertEqual(like.label, "Убрать отметку нравится")
        app.tabBars.buttons["Новая ветка"].tap()
        let input = app.textFields["postTextField"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["publishButton"].isEnabled)
        input.tap()
        input.typeText("Local persistence verification")
        capture("06-Composer")
        XCTAssertTrue(app.buttons["publishButton"].isEnabled)
        app.buttons["publishButton"].tap()
        XCTAssertTrue(app.staticTexts["Local persistence verification"].firstMatch.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Local persistence verification"].firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Новая ветка"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.typeText("Unpublished draft")
        app.buttons["cancelCompose"].tap()
        XCTAssertFalse(app.staticTexts["Unpublished draft"].exists)
    }

    @MainActor
    func test03LocalConversation() throws {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Сообщения"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Сообщения"].tap()
        app.staticTexts["soulbelief_"].firstMatch.tap()
        let input = app.textFields["messageInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Hello from the local app")
        app.buttons["sendMessage"].tap()
        XCTAssertTrue(app.staticTexts["Вы: Hello from the local app"].firstMatch.waitForExistence(timeout: 5))
        capture("07-Conversation")
        app.terminate()
        app.launch()
        app.tabBars.buttons["Сообщения"].tap()
        app.staticTexts["soulbelief_"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Вы: Hello from the local app"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func test04FeedsAndProfileEdit() throws {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.buttons["feedsButton"].waitForExistence(timeout: 10))
        app.buttons["feedsButton"].tap()
        capture("08-Feeds")
        app.buttons["Исчезающие публикации"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Пока нет исчезающих\nпубликаций"].waitForExistence(timeout: 5))
        capture("09-Disappearing")
        app.buttons["Назад"].tap()
        app.buttons["feedsButton"].tap()
        app.buttons["Создать ленту"].tap()
        let title = app.textFields["Название ленты"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("My feed")
        app.buttons["Добавить профили или темы"].tap()
        app.buttons.containing(.staticText, identifier: "lizzi_znaet").firstMatch.tap()
        app.buttons["Готово"].firstMatch.tap()
        app.buttons["Создайте ленту"].tap()
        XCTAssertTrue(app.buttons["My feed"].waitForExistence(timeout: 5))
        app.buttons["My feed"].tap()
        XCTAssertTrue(app.staticTexts["lizzi_znaet"].firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["Профиль"].tap()
        app.buttons["Редактировать профиль"].tap()
        let bio = app.textFields["Расскажите о себе"]
        XCTAssertTrue(bio.waitForExistence(timeout: 5))
        bio.tap()
        bio.typeText("Made with SwiftUI")
        app.buttons["Сохранить профиль"].tap()
        XCTAssertTrue(app.staticTexts["Made with SwiftUI"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.tabBars.buttons["Профиль"].tap()
        XCTAssertTrue(app.staticTexts["Made with SwiftUI"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test05ComposeKeepsTheCurrentNativeTabSelected() throws {
        let app = makeApp()
        app.launch()
        let messages = app.tabBars.buttons["Сообщения"]
        XCTAssertTrue(messages.waitForExistence(timeout: 10))
        messages.tap()
        XCTAssertTrue(messages.isSelected)
        app.tabBars.buttons["Новая ветка"].tap()
        XCTAssertTrue(app.buttons["cancelCompose"].waitForExistence(timeout: 5))
        app.buttons["cancelCompose"].tap()
        XCTAssertTrue(messages.waitForExistence(timeout: 5))
        XCTAssertTrue(messages.isSelected)
        XCTAssertTrue(app.staticTexts["soulbelief_"].firstMatch.exists)
        app.staticTexts["soulbelief_"].firstMatch.tap()
        XCTAssertTrue(app.textFields["messageInput"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(messages.waitForExistence(timeout: 5))
        XCTAssertTrue(messages.isSelected)
    }

    @MainActor
    func test06RefreshAndLayeredDrawerGestures() throws {
        let app = makeApp()
        app.launch()
        let feed = app.scrollViews["homeFeedScroll"]
        XCTAssertTrue(feed.waitForExistence(timeout: 10))
        let start = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let end = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        XCTAssertTrue(app.buttons["feedsButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["lizzi_znaet"].firstMatch.exists)
        XCTAssertTrue(app.tabBars.buttons["Главная"].isSelected)
        XCTAssertFalse(app.buttons["closeFeedsButton"].exists)
        capture("10-RefreshRestored")

        app.buttons["feedsButton"].tap()
        XCTAssertTrue(app.buttons["closeFeedsButton"].waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.buttons["closeFeedsButton"].frame.minX, app.frame.width * 0.7)
        capture("11-LayeredDrawer")
        let coveredScreen = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let closeTarget = app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5))
        coveredScreen.press(forDuration: 0.05, thenDragTo: closeTarget, withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons["feedsButton"].waitForExistence(timeout: 5))
        XCTAssertLessThan(app.buttons["feedsButton"].frame.minX, app.frame.width * 0.1)

        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.55))
        let openTarget = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.55))
        edge.press(forDuration: 0.05, thenDragTo: openTarget, withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons["closeFeedsButton"].waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.buttons["closeFeedsButton"].frame.minX, app.frame.width * 0.7)
        capture("12-EdgeOpenedDrawer")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.4)).tap()
        XCTAssertTrue(app.buttons["feedsButton"].waitForExistence(timeout: 5))
        XCTAssertLessThan(app.buttons["feedsButton"].frame.minX, app.frame.width * 0.1)

        let shortTarget = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.55))
        edge.press(forDuration: 0.05, thenDragTo: shortTarget, withVelocity: .slow, thenHoldForDuration: 0.4)
        XCTAssertTrue(app.buttons["feedsButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Главная"].isSelected)
    }

    @MainActor
    func test07DrawerOpensWithSwipeAcrossFeedAndClosesAcrossMenu() throws {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.buttons["feedsButton"].waitForExistence(timeout: 10))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons["closeFeedsButton"].waitForExistence(timeout: 3))
        XCTAssertGreaterThan(app.buttons["closeFeedsButton"].frame.minX, app.frame.width * 0.7)
        capture("13-FeedSwipeOpenedMenu")
        XCTAssertFalse(app.buttons["cancelCompose"].exists)
        let menuStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.65))
        let menuEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.65))
        menuStart.press(forDuration: 0.05, thenDragTo: menuEnd, withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons["feedsButton"].waitForExistence(timeout: 3))
        XCTAssertLessThan(app.buttons["feedsButton"].frame.minX, app.frame.width * 0.1)
        XCTAssertFalse(app.buttons["cancelCompose"].exists)
        XCTAssertTrue(app.tabBars.buttons["Главная"].isSelected)
    }

    @MainActor
    func test08PhotoCarouselDoesNotOpenDrawer() throws {
        let app = makeApp()
        app.launch()
        let feed = app.scrollViews["homeFeedScroll"]
        XCTAssertTrue(feed.waitForExistence(timeout: 10))
        let media = app.scrollViews["postMedia_post-olzhik-finance"]
        for _ in 0..<5 {
            if media.exists && media.isHittable && media.frame.minY > 130 && media.frame.maxY < app.frame.maxY - 120 { break }
            let start = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            let end = feed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(media.isHittable)
        let secondPhoto = app.images["finance_accounts"]
        XCTAssertTrue(secondPhoto.exists)
        let initialX = secondPhoto.frame.minX
        media.swipeLeft(velocity: .slow)
        let scrolledX = secondPhoto.frame.minX
        XCTAssertLessThan(scrolledX, initialX - 5)
        media.swipeRight(velocity: .slow)
        XCTAssertFalse(app.buttons["closeFeedsButton"].exists)
        XCTAssertGreaterThan(secondPhoto.frame.minX, scrolledX + 5)
        XCTAssertTrue(app.tabBars.buttons["Главная"].isSelected)
        capture("14-CarouselSwipeKeptFeed")
    }

    @MainActor
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["THREADS_STORAGE_SUITE"] = "ThreadsClone.UI." + UUID().uuidString
        return app
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
