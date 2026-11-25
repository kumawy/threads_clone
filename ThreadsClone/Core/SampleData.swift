import Foundation

enum SampleData {
    static let currentUser = Person(
        id: "muratov", username: "muratov.ak", name: "Aslan", avatar: "avatar_muratov_large",
        followers: 9
    )

    static let people: [Person] = [
        Person(id: "lizzi_znaet", username: "lizzi_znaet", name: "Лиззи", avatar: "avatar_lizzi_znaet", bio: "Мысли вслух. Про технологии и жизнь.", followers: 2340),
        Person(id: "demianets", username: "demianets", name: "Демьян", avatar: "avatar_demianets", bio: "Иногда пишу о том, что меня волнует.", followers: 1820),
        Person(id: "turarbek_marat", username: "turarbek_marat", name: "Турарбек Марат", avatar: "avatar_turarbek_marat", bio: "Снимаю жизнь такой, какая она есть.", followers: 3210),
        Person(id: "jasturke", username: "jasturke", name: "Жас Түрке", avatar: "avatar_jasturke", bio: "Каждый день — новая история.", followers: 870),
        Person(id: "to_tln", username: "to.tln", name: "Толғанай", avatar: "avatar_to_tln", followers: 1240),
        Person(id: "nazkaa_kampit", username: "nazkaa.kampit", name: "Назка", avatar: "avatar_nazkaa_kampit", followers: 965),
        Person(id: "skyinaz", username: "skyinaz", name: "Наз", avatar: "avatar_skyinaz", followers: 890),
        Person(id: "your1ion", username: "your1ion", name: "your1ion", avatar: "avatar_your1ion", followers: 1120),
        Person(id: "olzhikbro", username: "olzhikbro_", name: "Олжас", avatar: "avatar_olzhikbro", bio: "Делаю полезные приложения.", followers: 4560, isVerified: true),
        Person(id: "nik", username: "nik", name: "Ник", avatar: "avatar_nik", followers: 670),
        Person(id: "korn", username: "korn", name: "Korn", avatar: "avatar_korn", followers: 420),
        Person(id: "soulbelief_", username: "soulbelief_", name: "soulbelief_", avatar: "social_avatar_default64", followers: 381),
        Person(id: "akzhest", username: "akzhest", name: "Ақжест", avatar: "social_avatar_default64", followers: 746),
        Person(id: "shukimanova_m", username: "shukimanova_m", name: "Мадина", avatar: "social_avatar_default64", followers: 1250),
        Person(id: "erkebulan_090924", username: "erkebulan_090924", name: "Еркебұлан", avatar: "social_avatar_default36", followers: 254),
        Person(id: "arua", username: "aarua", name: "Arua", avatar: "profile_default_avatar")
    ]

    static let followedIDs: Set<String> = ["your1ion", "erkebulan_090924"]

    static var posts: [ThreadPost] {
        let now = Date()
        return [
            ThreadPost(
                id: "post-lizzi-claude", authorID: "lizzi_znaet",
                text: "Я одна не понимаю массового поклонения\nClaude Code?\n\nВсе вокруг орут, что он НАГОЛОВУ выше ChatGPT и Codex, но когда начинаешь спрашивать, в чём конкретно, получаешь какие-то восторженные рассказы вместо аргументов\n\nМожет, кто-нибудь объяснит?",
                timestamp: "3 ч.", likes: 9, replies: 32, createdAt: now.addingTimeInterval(-3 * 3600)
            ),
            ThreadPost(
                id: "post-demianets-mac", authorID: "demianets",
                text: "Люди, которые пользуются макбуками. В какой кассе вам выдают оплату за то, что вы хвалите это орудие пытки простых юзеров? У меня на моем виндовсом ноуте сломалась клавиша. И пока мой ноут в ремонте, пришлось взять у девушки ее старый мак. Я никогда в жизни не пользовался ничем более неудобным и контринтуитивным - там сделано через жопу буквально все: папки, программы, загрузки, скрины экрана (ОН НЕ КОПИРУЕТ СКРИНЫ ЭКРАНА СРАЗУ В БУФЕР!!!), это буквально сплошное страдание и смех",
                timestamp: "12 ч.", likes: 18, replies: 138, createdAt: now.addingTimeInterval(-12 * 3600)
            ),
            ThreadPost(
                id: "post-olzhik-finance", authorID: "olzhikbro",
                text: "Я создал приложение для учета финансов\nИ уже почти 10ТЫС скачивании ПО ВСЕМУ МИРУ😭🥺\nЭто очень удобно когда всё в одном месте!",
                timestamp: "20 ч.", likes: 173, replies: 24, reposts: 8,
                images: ["finance_expenses", "finance_accounts"], createdAt: now.addingTimeInterval(-20 * 3600)
            ),
            ThreadPost(id: "post-turarbek", authorID: "turarbek_marat", text: "Алматы сегодня особенно красивый. Иногда достаточно просто выйти на прогулку.", timestamp: "1 дн.", likes: 42, replies: 6, createdAt: now.addingTimeInterval(-86400)),
            ThreadPost(id: "reply-lizzi", authorID: "nik", text: "Мне кажется, всё зависит от задачи и привычного рабочего процесса.", timestamp: "2 ч.", likes: 3, replyToID: "post-lizzi-claude", createdAt: now.addingTimeInterval(-2 * 3600))
        ]
    }

    static let activities: [ActivityItem] = [
        ActivityItem(id: "activity-1", personID: "your1ion", kind: .following, text: "Подписался(-ась) на вас", time: "2 дн."),
        ActivityItem(id: "activity-2", personID: "erkebulan_090924", kind: .following, text: "Подписался(-ась) на вас", time: "17.10.26")
    ]

    static var messages: [ChatMessage] {
        let now = Date()
        return [
            ChatMessage(id: "message-soulbelief", personID: "soulbelief_", text: "🤣🤣🤣🤣🤣🤣", isOutgoing: false, date: now.addingTimeInterval(-8 * 3600)),
            ChatMessage(id: "message-akzhest", personID: "akzhest", text: "Вы отправили публикацию", isOutgoing: true, date: now.addingTimeInterval(-15 * 3600)),
            ChatMessage(id: "message-shukimanova", personID: "shukimanova_m", text: "осы сияқты жауап берген бола...", isOutgoing: false, date: now.addingTimeInterval(-14 * 86400)),
            ChatMessage(id: "message-to-tln", personID: "to_tln", text: "Уалейкум", isOutgoing: false, date: now.addingTimeInterval(-28 * 86400)),
            ChatMessage(id: "message-nazkaa", personID: "nazkaa_kampit", text: "Есть билеты?", isOutgoing: false, date: now.addingTimeInterval(-28 * 86400)),
            ChatMessage(id: "message-skyinaz", personID: "skyinaz", text: "Кернк", isOutgoing: false, date: now.addingTimeInterval(-28 * 86400))
        ]
    }
}
