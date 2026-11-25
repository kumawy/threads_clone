import SwiftUI

struct SettingsScreen: View {
    @Environment(ThreadsStore.self) private var store
    @State private var destination: SettingsDestination?
    @State private var showingProfiles = false
    @State private var confirmingLogout = false
    @State private var signedOut = false

    var body: some View {
        List {
            Button { destination = .account } label: {
                HStack(alignment: .top, spacing: 13) {
                    FigmaIcon("profile_settings_meta", size: 24)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Аккаунт Meta")
                            .font(.system(size: 16, weight: .medium))
                            .frame(height: 20, alignment: .leading)
                        Text("Пароль, безопасность, личные данные,\nкросс-профильные функции, рекламные")
                            .font(.system(size: 14))
                            .lineSpacing(1)
                            .foregroundStyle(ThreadTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                .contentShape(Rectangle())
            }
            .settingsRowStyle()
            .overlay(alignment: .bottom) {
                ThreadTheme.divider.frame(height: 0.5).padding(.horizontal, -16)
            }

            ForEach(SettingsDestination.menu) { item in
                Button { destination = item } label: {
                    HStack(spacing: 13) {
                        FigmaIcon(item.icon, size: 24)
                        Text(item.title)
                            .font(.system(size: 16, weight: .medium))
                            .lineSpacing(1)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: item.rowHeight, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .settingsRowStyle()
            }

            Color.clear
                .frame(height: 5)
                .settingsRowStyle()
                .overlay(alignment: .bottom) {
                    ThreadTheme.divider.frame(height: 0.5).padding(.horizontal, -16)
                }
            Button { showingProfiles = true } label: {
                Text("Переключить профиль")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 10 / 255, green: 171 / 255, blue: 247 / 255))
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .settingsRowStyle()
            Button { confirmingLogout = true } label: {
                Text("Выйти")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 1, green: 0, blue: 53 / 255))
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .settingsRowStyle()
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 0)
        .safeAreaInset(edge: .top, spacing: 0) {
            ThreadTheme.background
                .frame(height: 10)
                .overlay(alignment: .bottom) {
                    ThreadTheme.divider.frame(height: 0.5)
                }
        }
        .contentMargins(.bottom, 16, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(ThreadTheme.background)
        .foregroundStyle(ThreadTheme.white)
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ThreadTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(item: $destination) { item in
            SettingsDetailScreen(destination: item)
        }
        .sheet(isPresented: $showingProfiles) {
            ProfileSwitcherScreen()
        }
        .confirmationDialog("Выйти из профиля?", isPresented: $confirmingLogout, titleVisibility: .visible) {
            Button("Выйти", role: .destructive) { signedOut = true }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Ваши публикации и настройки сохранятся на этом устройстве.")
        }
        .fullScreenCover(isPresented: $signedOut) {
            LocalSignInScreen()
        }
    }
}

private enum SettingsDestination: String, Identifiable, Hashable {
    case account, parental, invite, notifications, saved, likes, archive, privacy, content, status, crossposting, more, help, information
    var id: String { rawValue }
    static let menu: [Self] = [.parental, .invite, .notifications, .saved, .likes, .archive, .privacy, .content, .status, .crossposting, .more, .help, .information]

    var title: String {
        switch self {
        case .account: "Аккаунт Meta"
        case .parental: "Родительский контроль для\nаккаунтов подростков"
        case .invite: "Пригласить друзей и подписаться"
        case .notifications: "Уведомления"
        case .saved: "Сохранено"
        case .likes: "Нравится"
        case .archive: "Архив"
        case .privacy: "Конфиденциальность"
        case .content: "Настройки контента"
        case .status: "Статус профиля"
        case .crossposting: "Публикация контента в\nнескольких профилях"
        case .more: "Ещё настройки"
        case .help: "Помощь"
        case .information: "Информация"
        }
    }

    var icon: String {
        switch self {
        case .account: "profile_settings_meta"
        case .parental: "profile_settings_parental"
        case .invite: "profile_settings_invite"
        case .notifications: "profile_settings_bell"
        case .saved: "profile_settings_bookmark"
        case .likes: "profile_settings_heart"
        case .archive: "profile_settings_archive"
        case .privacy: "profile_settings_lock"
        case .content: "profile_settings_content"
        case .status: "profile_settings_person"
        case .crossposting: "profile_settings_crosspost"
        case .more: "profile_settings_more"
        case .help: "profile_settings_help"
        case .information: "profile_settings_info"
        }
    }

    var rowHeight: CGFloat {
        switch self {
        case .parental: 61
        case .crossposting: 60
        default: 48
        }
    }
}

private extension View {
    func settingsRowStyle() -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(ThreadTheme.background)
            .buttonStyle(.plain)
    }
}

private struct SettingsDetailScreen: View {
    @Environment(ThreadsStore.self) private var store
    @AppStorage("settings.reduceMotion") private var reduceMotion = false
    @State private var feedback = ""
    @State private var feedbackSaved = false
    let destination: SettingsDestination

    var body: some View {
        Group {
            switch destination {
            case .saved, .likes, .archive:
                postCollection
            default:
                settingsForm
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThreadTheme.background)
        .foregroundStyle(ThreadTheme.white)
        .navigationTitle(destination.title.replacingOccurrences(of: "\n", with: " "))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ThreadTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(destination == .help ? .hidden : .visible, for: .tabBar)
        .onAppear {
            if destination == .help {
                feedback = UserDefaults.standard.string(forKey: "settings.localFeedback") ?? ""
            }
        }
    }

    private var settingsForm: some View {
        @Bindable var store = store
        return Form {
            switch destination {
            case .account:
                Section {
                    HStack(spacing: 14) {
                        AvatarView("profile_avatar", size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.profileName).font(.headline)
                            Text("@\(store.currentUser.username)").foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    LabeledContent("Профиль", value: "Threads")
                } header: {
                    Text("Личные данные")
                } footer: {
                    Text("Ваши данные хранятся только на этом устройстве.")
                }
                Section("Безопасность") {
                    LabeledContent("Данные профиля", value: "На устройстве")
                    Text("В этой демонстрации не требуется пароль. Вы можете выйти и снова открыть свой локальный профиль в настройках.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            case .parental:
                Section("Безопасное общение") {
                    Text("Обсуждайте безопасное общение с близкими и делайте регулярные перерывы.")
                    Text("Чтобы ограничить аудиторию публикаций, включите закрытый профиль в разделе «Конфиденциальность».")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Текущие настройки") {
                    LabeledContent("Профиль", value: store.isPrivate ? "Закрытый" : "Общедоступный")
                    LabeledContent("Уведомления", value: store.notificationsEnabled ? "Включены" : "Выключены")
                }
            case .invite:
                Section {
                    ShareLink(item: URL(string: "https://www.threads.net/@\(store.currentUser.username)")!) {
                        Label("Поделиться ссылкой на профиль", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Пригласите друзей в Threads и продолжайте общение в ветках.")
                }
                Section("Вам могут быть интересны") {
                    ForEach(store.people.filter { $0.id != store.currentUser.id }) { person in
                        HStack(spacing: 12) {
                            AvatarView(person.avatar, size: 40)
                            Text(person.username).font(.subheadline)
                            Spacer()
                            Button(store.followedIDs.contains(person.id) ? "Вы подписаны" : "Подписаться") {
                                store.toggleFollow(person.id)
                            }
                            .font(.caption.bold())
                            .buttonStyle(.borderless)
                        }
                    }
                }
            case .notifications:
                Section {
                    Toggle("Уведомления", isOn: $store.notificationsEnabled)
                } footer: {
                    Text("Вы можете изменить это предпочтение в любое время.")
                }
            case .privacy:
                Section {
                    Toggle("Закрытый профиль", isOn: $store.isPrivate)
                } footer: {
                    Text("В закрытом профиле ваши публикации видят только одобренные вами подписчики.")
                }
                Section("Ваш профиль") {
                    LabeledContent("Подписчики", value: "\(store.currentUser.followers)")
                    Text(store.isPrivate ? "Ваш профиль закрыт." : "Ваши ветки доступны всем.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            case .content:
                Section("Лента") {
                    LabeledContent("Подписки", value: "\(store.followedIDs.count)")
                    Text("В ленте «Подписки» отображаются публикации профилей, на которые вы подписаны.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Рекомендации профилей") {
                    Text("Чтобы скрыть рекомендацию, нажмите «×» в правом верхнем углу карточки профиля.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            case .status:
                Section {
                    Label("Профиль в порядке", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text("У вашего профиля нет ограничений. Вы можете создавать ветки, отвечать и подписываться на другие профили.")
                        .font(.subheadline)
                }
                Section("Ваш профиль") {
                    LabeledContent("Видимость", value: store.isPrivate ? "Закрытый" : "Общедоступный")
                    LabeledContent("Публикации", value: "\(store.posts.filter { $0.authorID == store.currentUser.id }.count)")
                }
            case .crossposting:
                Section {
                    ShareLink(item: URL(string: "https://www.threads.net/@\(store.currentUser.username)")!) {
                        Label("Поделиться профилем", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Поделиться в других приложениях")
                } footer: {
                    Text("Для публикации ветки в другом приложении нажмите кнопку «Поделиться» под ней и выберите получателя.")
                }
            case .more:
                Section("Приложение") {
                    LabeledContent("Язык", value: "Русский")
                    Toggle("Уменьшение движения", isOn: $reduceMotion)
                    LabeledContent("Оформление", value: "Тёмное")
                }
                Section {
                    Text("Изменения настроек сохраняются автоматически.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            case .help:
                Section("Частые вопросы") {
                    DisclosureGroup("Как создать ветку?") {
                        Text("Нажмите «+» в нижней панели, напишите текст и нажмите «Опубликовать».")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    DisclosureGroup("Где находятся сохранённые ветки?") {
                        Text("Откройте меню публикации и выберите «Сохранить». Она появится в разделе «Сохранено» в настройках.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    DisclosureGroup("Сохраняются ли мои изменения?") {
                        Text("Да, публикации, реакции, подписки и настройки сохраняются локально на этом устройстве.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Section {
                    TextField("Опишите проблему или идею", text: $feedback, axis: .vertical)
                        .lineLimit(4...8)
                    Button("Сохранить отзыв на устройстве") {
                        UserDefaults.standard.set(feedback, forKey: "settings.localFeedback")
                        feedbackSaved = true
                    }
                    .disabled(feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("Обратная связь")
                } footer: {
                    if feedbackSaved { Text("Отзыв сохранён. Спасибо!") }
                }
            case .information:
                Section {
                    Text("Threads")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    LabeledContent("Версия", value: "1.0")
                    LabeledContent("Хранение данных", value: "На устройстве")
                }
                Section("О приложении") {
                    Text("Интерактивная демонстрация Threads. Общайтесь в ветках, находите профили и настраивайте своё пространство.")
                    Text("Это самостоятельная демонстрация интерфейса, не связанная с Meta.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            case .saved, .likes, .archive:
                EmptyView()
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 16, for: .scrollContent)
        .background(ThreadTheme.background)
    }

    private var postCollection: some View {
        let posts = store.posts.filter { post in
            if destination == .archive {
                return post.authorID == store.currentUser.id && store.isExpired(post)
            }
            return !store.isExpired(post) && (destination == .saved ? post.isSaved : post.isLiked)
        }
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(posts) { post in
                    ThreadPostRow(post: post)
                }
            }
            .padding(.bottom, 16)
        }
        .overlay {
            if posts.isEmpty {
                ContentUnavailableView {
                    Label(collectionEmptyTitle, systemImage: collectionIcon)
                } description: {
                    Text(collectionEmptyDescription)
                }
            }
        }
    }

    private var collectionEmptyTitle: String {
        switch destination {
        case .archive: "В архиве пока пусто"
        case .saved: "Сохранённых веток пока нет"
        default: "Здесь появятся понравившиеся ветки"
        }
    }

    private var collectionEmptyDescription: String {
        switch destination {
        case .archive: "Исчезающие ветки появятся здесь через 24 часа после публикации. Архив виден только вам."
        case .saved: "Сохраняйте интересные публикации через меню ветки."
        default: "Нажмите на сердце под публикацией, чтобы добавить её сюда."
        }
    }

    private var collectionIcon: String {
        switch destination {
        case .archive: "clock.arrow.circlepath"
        case .saved: "bookmark"
        default: "heart"
        }
    }
}

private struct ProfileSwitcherScreen: View {
    @Environment(ThreadsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        AvatarView("profile_avatar", size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.profileName).font(.headline)
                            Text(store.currentUser.username).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text("На этом устройстве используется один локальный профиль.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThreadTheme.background)
            .navigationTitle("Переключить профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}

private struct LocalSignInScreen: View {
    @Environment(ThreadsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("Threads").font(.largeTitle.bold())
            AvatarView("profile_avatar", size: 88)
            Text("Вы вышли из профиля").font(.title3.bold())
            Text("Ваши данные сохранены на этом устройстве.")
                .font(.subheadline)
                .foregroundStyle(ThreadTheme.secondary)
                .multilineTextAlignment(.center)
            Button { dismiss() } label: {
                Text("Войти как \(store.currentUser.username)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ThreadTheme.white, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(ThreadTheme.background)
            }
            Spacer()
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThreadTheme.background)
        .foregroundStyle(ThreadTheme.white)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }
}
