import SwiftUI

struct ProfileScreen: View {
    @Environment(ThreadsStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("settings.reduceMotion") private var reduceMotion = false
    @State private var selectedTab: ProfileTab = .threads
    @State private var sheet: ProfileSheet?
    @State private var dismissedRecommendations: Set<String> = []
    let onCompose: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader
                    .padding(.horizontal, 16)
                recommendations
                    .padding(.top, 28)
                profileTabs
                    .padding(.top, 13)
                profileContent
            }
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .background(ThreadTheme.background)
        .foregroundStyle(ThreadTheme.white)
        .toolbar {
            if #available(iOS 26.0, *) {
                profileToolbar.sharedBackgroundVisibility(.hidden)
            } else {
                profileToolbar
            }
        }
        .toolbarBackground(ThreadTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(item: $sheet) { destination in
            switch destination {
            case .edit:
                EditProfileScreen()
            case .statistics:
                ProfileStatisticsScreen()
            case .followers:
                ProfilePeopleScreen(title: "Подписчики", searchable: false)
            case .search:
                ProfilePeopleScreen(title: "Поиск", searchable: true)
            case .recommendation(let recommendation):
                RecommendedProfileScreen(recommendation: recommendation)
            }
        }
    }

    @ToolbarContentBuilder private var profileToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { sheet = .search } label: {
                FigmaIcon("profile_search", size: 24)
            }
            .accessibilityLabel("Поиск профилей")
            NavigationLink {
                SettingsScreen()
            } label: {
                FigmaIcon("profile_settings", size: 24)
            }
            .accessibilityLabel("Настройки")
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.profileName)
                        .font(.system(size: 24, weight: .heavy))
                        .lineLimit(2)
                        .frame(minHeight: 30, alignment: .leading)
                    Text(store.currentUser.username)
                        .font(.system(size: 14))
                        .frame(height: 19)
                }
                .padding(.top, 18)
                Spacer(minLength: 20)
                AvatarView("profile_avatar", size: 64)
                    .overlay(alignment: .bottomLeading) {
                        Button(action: onCompose) {
                            ZStack {
                                Image("profile_story_badge")
                                    .renderingMode(.original)
                                Image("profile_story_ring")
                                    .resizable()
                                    .frame(width: 25, height: 25)
                                FigmaIcon("profile_plus", size: 14)
                            }
                            .frame(width: 34, height: 34)
                        }
                        .offset(x: -26, y: 1)
                        .accessibilityLabel("Добавить публикацию")
                    }
            }
            .frame(minHeight: 72, alignment: .top)

            if !store.bio.isEmpty {
                Text(store.bio)
                    .font(.subheadline)
                    .padding(.top, 8)
            }
            if !store.link.isEmpty {
                Link(store.link, destination: URL(string: store.link.hasPrefix("http") ? store.link : "https://\(store.link)") ?? URL(string: "https://threads.net")!)
                    .font(.subheadline)
                    .foregroundStyle(ThreadTheme.secondary)
                    .padding(.top, 6)
            }

            Button { sheet = .followers } label: {
                HStack(spacing: 8) {
                    HStack(spacing: -4) {
                        ForEach(["profile_follower_one", "profile_follower_two", "profile_follower_three"], id: \.self) { name in
                            AvatarView(name, size: 18)
                        }
                    }
                    Text("Подписчики: \(store.currentUser.followers)")
                        .font(.system(size: 14))
                        .foregroundStyle(ThreadTheme.secondary)
                }
                .frame(height: 20)
            }
            .padding(.top, 12)
            .accessibilityLabel("Подписчики: \(store.currentUser.followers). Открыть список")

            HStack(spacing: 10) {
                Button { sheet = .edit } label: {
                    Text("Редактировать профиль")
                        .font(.system(size: 12, weight: .bold))
                        .minimumScaleFactor(0.85)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .profileSecondaryButton()
                Button { sheet = .statistics } label: {
                    Text("Смотреть статистику")
                        .font(.system(size: 13, weight: .bold))
                        .minimumScaleFactor(0.85)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .profileSecondaryButton()
                ShareLink(item: URL(string: "https://www.threads.net/@\(store.currentUser.username)")!) {
                    FigmaIcon("profile_share", size: 18)
                        .frame(width: 34)
                }
                .profileSecondaryButton()
                .accessibilityLabel("Поделиться профилем")
            }
            .padding(.top, 20)
        }
    }

    private var recommendations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Рекомендации для вас")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ThreadTheme.secondary)
                .frame(height: 19)
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(ProfileRecommendation.samples.filter { !dismissedRecommendations.contains($0.id) }) { recommendation in
                        ProfileRecommendationCard(
                            recommendation: recommendation,
                            followed: store.followedIDs.contains(recommendation.storeID(in: store)),
                            onOpen: { sheet = .recommendation(recommendation) },
                            onFollow: { store.toggleFollow(recommendation.storeID(in: store)) },
                            onDismiss: {
                                withAnimation(reduceMotion || systemReduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                    _ = dismissedRecommendations.insert(recommendation.id)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private var profileTabs: some View {
        VStack(spacing: 0) {
            ThreadTheme.divider.frame(height: 0.5)
            HStack(spacing: 10) {
                ForEach(ProfileTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(selectedTab == tab ? ThreadTheme.white : ThreadTheme.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .overlay(alignment: .bottom) {
                                if selectedTab == tab {
                                    ThreadTheme.white.frame(height: 0.5)
                                }
                            }
                    }
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
            ThreadTheme.border.frame(height: 0.5)
        }
    }

    @ViewBuilder private var profileContent: some View {
        if visiblePosts.isEmpty {
            Text(selectedTab.emptyMessage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ThreadTheme.secondary)
                .frame(height: 22)
                .frame(maxWidth: .infinity)
                .padding(.top, 77)
                .padding(.bottom, 45)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(visiblePosts) { post in
                    ThreadPostRow(post: post)
                }
            }
        }
    }

    private var visiblePosts: [ThreadPost] {
        let activePosts = store.posts.filter { !store.isExpired($0) }
        switch selectedTab {
        case .threads:
            return activePosts.filter { $0.authorID == store.currentUser.id && $0.replyToID == nil }
        case .replies:
            return activePosts.filter { $0.authorID == store.currentUser.id && $0.replyToID != nil }
        case .media:
            return activePosts.filter { $0.authorID == store.currentUser.id && !$0.images.isEmpty }
        case .reposts:
            return activePosts.filter(\.isReposted)
        }
    }
}

private enum ProfileTab: String, CaseIterable, Identifiable {
    case threads = "Ветки"
    case replies = "Ответы"
    case media = "Медиа"
    case reposts = "Репосты"
    var id: String { rawValue }
    var emptyMessage: String {
        switch self {
        case .threads: "Веток пока нет"
        case .replies: "Ответов пока нет"
        case .media: "Медиа пока нет"
        case .reposts: "Репостов пока нет"
        }
    }
}

private enum ProfileSheet: Identifiable {
    case edit, statistics, followers, search
    case recommendation(ProfileRecommendation)
    var id: String {
        switch self {
        case .edit: "edit"
        case .statistics: "statistics"
        case .followers: "followers"
        case .search: "search"
        case .recommendation(let person): person.id
        }
    }
}

private struct ProfileRecommendation: Identifiable {
    let id: String
    let name: String
    let username: String
    let avatar: String
    static let samples = [
        Self(id: "turarbek", name: "Turarbek Marat", username: "turarbek_marat", avatar: "profile_turarbek"),
        Self(id: "jasturke", name: "JASTURKE", username: "genkogomu", avatar: "profile_jasturke"),
        Self(id: "arua", name: "Arua", username: "aarua", avatar: "profile_default_avatar")
    ]

    @MainActor func storeID(in store: ThreadsStore) -> String {
        store.people.first { $0.username == username }?.id ?? id
    }
}

private struct ProfileRecommendationCard: View {
    let recommendation: ProfileRecommendation
    let followed: Bool
    let onOpen: () -> Void
    let onFollow: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpen) {
                VStack(spacing: 0) {
                    AvatarView(recommendation.avatar, size: 88)
                        .padding(.top, 12)
                    Text(recommendation.name)
                        .font(.system(size: 14, weight: .heavy))
                        .lineLimit(1)
                        .frame(height: 19)
                        .padding(.top, 12)
                    Text(recommendation.username)
                        .font(.system(size: 12))
                        .foregroundStyle(ThreadTheme.secondary)
                        .lineLimit(1)
                        .frame(height: 17)
                        .padding(.top, 2)
                }
            }
            Button(action: onFollow) {
                Text(followed ? "Вы подписаны" : "Подписаться")
                    .font(.system(size: 15, weight: .bold))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(followed ? ThreadTheme.border : ThreadTheme.white, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(followed ? ThreadTheme.white : ThreadTheme.background)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .frame(width: 150, height: 206.67)
        .background(ThreadTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                FigmaIcon("profile_close", size: 12)
                    .foregroundStyle(ThreadTheme.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .padding(.top, 2)
            .padding(.trailing, 3)
            .accessibilityLabel("Скрыть рекомендацию \(recommendation.name)")
        }
    }
}

private extension View {
    func profileSecondaryButton() -> some View {
        frame(height: 35)
            .background(ThreadTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(ThreadTheme.white)
    }

    @ViewBuilder func profileSearchable(_ enabled: Bool, text: Binding<String>) -> some View {
        if enabled {
            searchable(text: text, prompt: "Имя или имя пользователя")
        } else {
            self
        }
    }
}

private struct EditProfileScreen: View {
    @Environment(ThreadsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var bio = ""
    @State private var link = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        AvatarView("profile_avatar", size: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.currentUser.username).font(.headline)
                            Text("Ваш профиль Threads").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Имя") {
                    TextField("Имя", text: $name)
                }
                Section("Биография") {
                    TextField("Расскажите о себе", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Ссылка") {
                    TextField("Добавить ссылку", text: $link)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThreadTheme.background)
            .navigationTitle("Редактировать профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Отменить")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.updateProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines), bio: bio, link: link)
                        dismiss()
                    } label: { Image(systemName: "checkmark") }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Сохранить профиль")
                }
            }
            .onAppear {
                name = store.profileName
                bio = store.bio
                link = store.link
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ProfileStatisticsScreen: View {
    @Environment(ThreadsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Обзор профиля") {
                    LabeledContent("Подписчики", value: "\(store.currentUser.followers)")
                    LabeledContent("Публикации", value: "\(ownPosts.count)")
                    LabeledContent("Нравится", value: "\(ownPosts.reduce(0) { $0 + $1.likes })")
                    LabeledContent("Ответы", value: "\(ownPosts.reduce(0) { $0 + $1.replies })")
                }
                Section {
                    Text("Статистика отражает активность в этом приложении. Создайте новую ветку, чтобы увидеть её здесь.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThreadTheme.background)
            .navigationTitle("Статистика")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var ownPosts: [ThreadPost] {
        store.posts.filter { $0.authorID == store.currentUser.id }
    }
}

private struct ProfilePeopleScreen: View {
    @Environment(ThreadsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    let title: String
    let searchable: Bool

    var body: some View {
        NavigationStack {
            List(filteredPeople) { person in
                HStack(spacing: 12) {
                    AvatarView(person.avatar, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(person.username).font(.subheadline.bold())
                        Text(person.name).font(.subheadline).foregroundStyle(ThreadTheme.secondary)
                    }
                    Spacer()
                    Button {
                        store.toggleFollow(person.id)
                    } label: {
                        Text(store.followedIDs.contains(person.id) ? "Вы подписаны" : "Подписаться")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThreadTheme.border))
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(ThreadTheme.background)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(ThreadTheme.background)
            .overlay {
                if filteredPeople.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .profileSearchable(searchable, text: $query)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var filteredPeople: [Person] {
        let people = searchable ? store.people : Array(store.people.prefix(store.currentUser.followers))
        return people.filter { person in
            person.id != store.currentUser.id && (query.isEmpty || person.name.localizedCaseInsensitiveContains(query) || person.username.localizedCaseInsensitiveContains(query))
        }
    }
}

private struct RecommendedProfileScreen: View {
    @Environment(ThreadsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let recommendation: ProfileRecommendation

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                AvatarView(recommendation.avatar, size: 88)
                Text(recommendation.name).font(.title2.bold())
                Text(recommendation.username).foregroundStyle(ThreadTheme.secondary)
                Button {
                    store.toggleFollow(recommendation.storeID(in: store))
                } label: {
                    Text(store.followedIDs.contains(recommendation.storeID(in: store)) ? "Вы подписаны" : "Подписаться")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ThreadTheme.white, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(ThreadTheme.background)
                }
                Text("Публикации этого профиля появятся в вашей ленте после подписки.")
                    .font(.subheadline)
                    .foregroundStyle(ThreadTheme.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ThreadTheme.background)
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
