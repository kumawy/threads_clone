import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case home, messages, activity, profile, compose
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .home: "Главная"
        case .messages: "Сообщения"
        case .activity: "Действия"
        case .profile: "Профиль"
        case .compose: "Новая ветка"
        }
    }
    func iconAsset(isSelected: Bool) -> String {
        switch self {
        case .home: isSelected ? "home_fill" : "home"
        case .messages: isSelected ? "send_fill" : "send"
        case .activity: "heart"
        case .profile: isSelected ? "person_fill" : "person"
        case .compose: "plus"
        }
    }
}

struct RootView: View {
    @State private var selectedTab = AppTab.home
    @State private var showComposer = false
    @State private var replyPost: ThreadPost?
    @State private var showDrawer = false
    @State private var drawerTranslation: CGFloat = 0
    @State private var selectedFeed = FeedDestination.forYou
    @State private var customFeed: LocalFeed?
    @State private var mediaGestureExclusions: [CGRect] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThreadsStore.self) private var store
    @AppStorage("settings.reduceMotion") private var appReduceMotion = false

    var body: some View {
        GeometryReader { geometry in
            let drawerWidth = min(330, geometry.size.width * 0.8)
            let progress = drawerProgress(width: drawerWidth)
            // The card takes the screen's own corner shape as soon as it moves, as in the reference.
            let cornerRadius: CGFloat = progress > 0 ? 40 : 0
            ZStack(alignment: .topLeading) {
                ThreadTheme.background.ignoresSafeArea()
                FeedDrawer(selectedFeed: $selectedFeed, customFeed: $customFeed, onClose: closeDrawer)
                    .frame(width: drawerWidth, height: geometry.size.height, alignment: .topLeading)
                    // The menu brightens from about 20 % and is fully lit by 60 % of the way open.
                    .opacity(min(1, 0.2 + 1.3 * progress))
                    .contentShape(.rect)
                    .allowsHitTesting(showDrawer)
                    .accessibilityHidden(!showDrawer)
                mainContent(drawerWidth: drawerWidth)
                    .allowsHitTesting(!showDrawer)
                    .accessibilityHidden(showDrawer)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    // Extend the card canvas, keeping the TabView's resting safe-area layout.
                    .padding(.top, geometry.safeAreaInsets.top)
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                    .background(ThreadTheme.background)
                    .overlay {
                        // Measured from the reference: a mid-grey veil that lifts the card above the menu.
                        Color(white: 50.0 / 255.0).opacity(0.59 * progress)
                            .allowsHitTesting(false)
                        if showDrawer {
                            Button(action: closeDrawer) {
                                Color.clear.contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Закрыть меню лент")
                            .accessibilityIdentifier("closeFeedsButton")
                            .accessibilityAction(.escape, closeDrawer)
                            .transition(.identity)
                        }
                    }
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: cornerRadius, bottomLeadingRadius: cornerRadius, style: .continuous))
                    .offset(x: drawerWidth * progress, y: -geometry.safeAreaInsets.top)
                    .transaction { transaction in
                        if reduceMotion || appReduceMotion {
                            transaction.animation = nil
                            transaction.disablesAnimations = true
                        }
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .modifier(NativeDrawerPanGesture(
                enabled: selectedTab == .home && !showComposer && scenePhase == .active,
                canBegin: { start, velocity in
                    canBeginDrawerPan(start: start, velocity: velocity,
                                      feedBottom: geometry.frame(in: .global).maxY - 70)
                },
                onChange: { translation in
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { drawerTranslation = translation }
                },
                onEnd: { translation, velocity, cancelled in
                    let projected = (showDrawer ? drawerWidth : 0) + translation + velocity * 0.2
                    withAnimation(drawerAnimation) {
                        if !cancelled { showDrawer = projected > drawerWidth * 0.5 }
                        drawerTranslation = 0
                    }
                }
            ))
            .onPreferenceChange(FeedMediaGestureExclusion.self) { mediaGestureExclusions = $0 }
        }
        .background(ThreadTheme.background)
        .foregroundStyle(ThreadTheme.white)
        .task {
            while !Task.isCancelled {
                store.refreshTime()
                do { try await Task.sleep(for: .seconds(60)) } catch { break }
            }
        }
        .onChange(of: scenePhase) { if scenePhase == .active { store.refreshTime() } }
        .sheet(isPresented: $showComposer, onDismiss: { replyPost = nil }) {
            ComposerScreen(replyTo: replyPost)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding {
            selectedTab
        } set: { tab in
            // Compose is an action: the current section remains selected behind its sheet.
            if tab == .compose { compose() }
            else { selectedTab = tab }
        }
    }

    @ViewBuilder
    private func mainContent(drawerWidth: CGFloat) -> some View {
        if #available(iOS 18.0, *) {
            TabView(selection: tabSelection) {
                Tab(value: AppTab.home) { tabContent(.home, drawerWidth: drawerWidth) } label: { tabImage(.home) }
                    .accessibilityLabel(Text(AppTab.home.title))
                Tab(value: AppTab.messages) { tabContent(.messages, drawerWidth: drawerWidth) } label: { tabImage(.messages) }
                    .accessibilityLabel(Text(AppTab.messages.title))
                Tab(value: AppTab.compose) { tabContent(.compose, drawerWidth: drawerWidth) } label: { tabImage(.compose) }
                    .accessibilityLabel(Text(AppTab.compose.title))
                Tab(value: AppTab.activity) { tabContent(.activity, drawerWidth: drawerWidth) } label: { tabImage(.activity) }
                    .accessibilityLabel(Text(AppTab.activity.title))
                Tab(value: AppTab.profile) { tabContent(.profile, drawerWidth: drawerWidth) } label: { tabImage(.profile) }
                    .accessibilityLabel(Text(AppTab.profile.title))
            }
            .sensoryFeedback(.selection, trigger: selectedTab)
        } else {
            TabView(selection: tabSelection) {
                ForEach([AppTab.home, .messages, .compose, .activity, .profile]) { tab in
                    tabContent(tab, drawerWidth: drawerWidth)
                        .tabItem { tabImage(tab).accessibilityLabel(Text(tab.title)) }
                        .tag(tab)
                }
            }
            .sensoryFeedback(.selection, trigger: selectedTab)
        }
    }

    private func tabImage(_ tab: AppTab) -> Image {
        Image(tab.iconAsset(isSelected: selectedTab == tab)).renderingMode(.original)
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab, drawerWidth: CGFloat) -> some View {
        switch tab {
        case .home:
            NavigationStack {
                HomeScreen(feed: selectedFeed, customFeed: customFeed, onBackFeed: { selectedFeed = .forYou; customFeed = nil }, onOpenDrawer: openDrawer, onCompose: compose, onReply: reply)
            }
        case .messages:
            NavigationStack { MessagesScreen() }
        case .activity:
            NavigationStack { ActivityScreen() }
        case .profile:
            NavigationStack { ProfileScreen(onCompose: compose) }
        case .compose:
            Color.clear.accessibilityHidden(true)
        }
    }

    private func drawerProgress(width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        return min(max((showDrawer ? 1 : 0) + drawerTranslation / width, 0), 1)
    }

    private var drawerAnimation: Animation? {
        reduceMotion || appReduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.9)
    }

    private func canBeginDrawerPan(start: CGPoint, velocity: CGPoint, feedBottom: CGFloat) -> Bool {
        guard abs(velocity.x) > abs(velocity.y) * 1.2 else { return false }
        if showDrawer { return velocity.x < 0 }
        return velocity.x > 0 && start.y < feedBottom &&
            !mediaGestureExclusions.contains(where: { $0.contains(start) })
    }

    private func setDrawerOpen(_ isOpen: Bool) {
        withAnimation(drawerAnimation) {
            showDrawer = isOpen
        }
    }

    private func openDrawer() { setDrawerOpen(true) }
    private func closeDrawer() { setDrawerOpen(false) }
    private func compose() { replyPost = nil; showComposer = true }
    private func reply(_ post: ThreadPost) { replyPost = post; showComposer = true }
}

struct FeedMediaGestureExclusion: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

