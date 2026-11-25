import SwiftUI

enum FeedDestination: String, CaseIterable, Identifiable {
    case forYou = "Для вас"
    case following = "Подписки"
    case disappearing = "Исчезающие публикации"
    case liked = "Нравится"
    case saved = "Сохранённое"
    var id: String { rawValue }
}

struct HomeScreen: View {
    @Environment(ThreadsStore.self) private var store
    let feed: FeedDestination
    var customFeed: LocalFeed? = nil
    let onBackFeed: () -> Void
    let onOpenDrawer: () -> Void
    let onCompose: () -> Void
    let onReply: (ThreadPost) -> Void
    @State private var showSearch = false
    @State private var ghostComposer = false
    @State private var refresh = FeedRefreshState()
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("settings.reduceMotion") private var appReduceMotion = false

    private var reduceMotion: Bool { systemReduceMotion || appReduceMotion }
    private var isRefreshing: Bool { refresh.requestID != nil }

    private var posts: [ThreadPost] {
        store.posts.filter { post in
            if store.isExpired(post) { return false }
            if let customFeed { return customFeed.personIDs.contains(post.authorID) && post.replyToID == nil && !post.isDisappearing }
            return switch feed {
            case .forYou: !post.isDisappearing && post.replyToID == nil
            case .following: store.followedIDs.contains(post.authorID) && !post.isDisappearing && post.replyToID == nil
            case .liked: post.isLiked
            case .saved: post.isSaved
            case .disappearing: post.isDisappearing
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .offset(y: reduceMotion ? 0 : refresh.headerOffset)
                .zIndex(1)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        composePrompt.id("top")
                        if feed == .forYou {
                            ThreadDivider().overlay {
                                Button {
                                    withAnimation { proxy.scrollTo("top", anchor: .top) }
                                } label: {
                                    Text("Потерялись в ленте? Назад ›")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(ThreadTheme.secondary)
                                        .padding(.horizontal, 12).frame(height: 28)
                                        .background(ThreadTheme.background, in: .capsule)
                                        .overlay(Capsule().stroke(ThreadTheme.border, lineWidth: 1))
                                }
                            }
                            .padding(.bottom, 16)
                        } else { ThreadDivider() }
                        if posts.isEmpty {
                            emptyState.padding(.top, feed == .disappearing ? 150 : 110)
                        } else {
                            ForEach(posts) { post in
                                RefreshingPostRow(post: post,
                                                  isLoading: isRefreshing && post.id != posts.first?.id,
                                                  reduceMotion: reduceMotion,
                                                  onReply: onReply)
                                ThreadDivider()
                            }
                        }
                    }
                    .padding(.bottom, 16)
                    .background {
                        if #unavailable(iOS 18.0) {
                            GeometryReader { geometry in
                                Color.clear.preference(key: FeedPullPreference.self,
                                                       value: max(0, geometry.frame(in: .named("homeFeedScroll")).minY).rounded())
                            }
                        }
                    }
                }
                .coordinateSpace(.named("homeFeedScroll"))
                .modifier(FeedPullObserver(onChange: { distance in
                    refresh.updatePull(distance)
                }, onDragChange: { dragging, distance in
                    if let distance { refresh.updatePull(distance) }
                    refresh.setDragging(dragging)
                }))
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("homeFeedScroll")
            }
        }
        .background(ThreadTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSearch) { NavigationStack { SearchScreen() } }
        .sheet(isPresented: $ghostComposer) { ComposerScreen(isDisappearing: true) }
        .task(id: refresh.requestID) {
            guard let id = refresh.requestID else { return }
            await runRefresh(id)
        }
        .onDisappear(perform: cancelRefresh)
        .onChange(of: feed) { cancelRefresh() }
        .onChange(of: customFeed?.id) { cancelRefresh() }
    }

    private var header: some View {
        HStack {
            if feed != .forYou && customFeed == nil {
                Button(action: onBackFeed) {
                    HStack(spacing: 4) { FigmaIcon("back", size: 16); Text("Назад").font(.system(size: 15)) }
                        .frame(width: 76, height: 44, alignment: .leading)
                }.accessibilityLabel("Назад")
            } else {
                Button(action: onOpenDrawer) {
                    FigmaIcon("menu", size: 21).foregroundStyle(ThreadTheme.secondary).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Ленты").accessibilityIdentifier("feedsButton")
            }
            Spacer()
            if feed == .forYou {
                ThreadsWordmark(erase: reduceMotion ? 0 : refresh.titleFade)
                    .animation(reduceMotion ? nil : .linear(duration: HomeRefreshMotion.rewriteDuration),
                               value: refresh.recoveryFade)
                    .accessibilityIdentifier("threadsWordmark")
            } else {
                VStack(spacing: 2) {
                    Text(customFeed?.name ?? feed.rawValue).font(.system(size: feed == .disappearing ? 14 : 17, weight: .bold))
                    if feed == .disappearing {
                        Text("Подписки").font(.system(size: 12)).foregroundStyle(ThreadTheme.secondary)
                    }
                }
            }
            Spacer()
            if feed != .forYou && customFeed == nil {
                Color.clear.frame(width: 76, height: 44)
            } else {
                Button { showSearch = true } label: {
                    FigmaIcon("search").foregroundStyle(ThreadTheme.secondary).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Поиск").accessibilityIdentifier("searchButton")
            }
        }
        .padding(.horizontal, 6).frame(height: 48)
    }

    @MainActor private func runRefresh(_ id: UUID) async {
        defer { refresh.finish(id) }
        do {
            // The logo stays un-written while the placeholders shimmer.
            try await Task.sleep(for: HomeRefreshMotion.loadDuration)
            guard refresh.requestID == id, !Task.isCancelled else { return }
            store.refreshTime()
            // Clearing the request swaps the posts back in and lets the wordmark write itself again.
            refresh.finish(id)
        } catch {
            // The view owns this task; leaving the feed cancels the presentation too.
        }
    }

    @MainActor private func cancelRefresh() {
        refresh.cancel()
    }

    private var composePrompt: some View {
        Button(action: feed == .disappearing ? { ghostComposer = true } : onCompose) {
            HStack(alignment: .top, spacing: 8) {
                AvatarView("avatar_muratov_clean")
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.currentUser.username).font(.system(size: 14, weight: .heavy))
                    Text(feed == .disappearing ? "Поделитесь мыслями…" : "Что нового?")
                        .font(.system(size: 14)).foregroundStyle(ThreadTheme.secondary)
                        .padding(feed == .disappearing ? 12 : 0)
                        .overlay {
                            if feed == .disappearing { Capsule().strokeBorder(ThreadTheme.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])) }
                        }
                }
                Spacer()
            }
            .padding(.horizontal, 8).padding(.top, 20).padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain).accessibilityLabel("Что нового? Создать ветку")
    }

    @ViewBuilder private var emptyState: some View {
        switch feed {
        case .disappearing:
            VStack(spacing: 22) {
                FigmaIcon("ghost", size: 64).foregroundStyle(ThreadTheme.secondary)
                ThreadEmptyState(title: "Пока нет исчезающих\nпубликаций", detail: "Исчезающие публикации попадают в архив через 24 часа. Вы можете выбрать, где будут показываться ответы: в сообщениях и в публикации.", icon: "")
            }
        case .following:
            ThreadEmptyState(title: "Здесь будут ваши подписки", detail: "Найдите интересных людей и подпишитесь, чтобы видеть их публикации.", icon: "person.2")
        case .liked:
            ThreadEmptyState(title: "Пока нет отметок «Нравится»", detail: "Публикации, которые вам понравятся, появятся здесь.", icon: "heart")
        case .saved:
            ThreadEmptyState(title: "Пока ничего не сохранено", detail: "Сохраняйте публикации, чтобы вернуться к ним позже.", icon: "bookmark")
        default: EmptyView()
        }
    }
}

struct SearchScreen: View {
    @Environment(ThreadsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Person] {
        store.people.filter { $0.id != store.currentUser.id && (query.isEmpty || $0.username.localizedCaseInsensitiveContains(query) || $0.name.localizedCaseInsensitiveContains(query)) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(results) { person in
                    HStack(spacing: 12) {
                        AvatarView(person.avatar)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.username).font(.system(size: 15, weight: .semibold))
                            Text(person.name).font(.system(size: 14)).foregroundStyle(ThreadTheme.secondary)
                        }
                        Spacer()
                        Button(store.followedIDs.contains(person.id) ? "Вы подписаны" : "Подписаться") { store.toggleFollow(person.id) }
                            .buttonStyle(ThreadPillStyle(selected: !store.followedIDs.contains(person.id)))
                    }
                    .padding(16)
                    ThreadDivider().padding(.leading, 72)
                }
                if results.isEmpty { ContentUnavailableView.search(text: query) }
            }
        }
        .background(ThreadTheme.background)
        .navigationTitle("Поиск").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Поиск")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
    }
}
